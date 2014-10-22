global class VEEVA_PS_POPULATE_CYCLE_PLAN_FIELDS implements Database.Batchable<sObject>,Schedulable{
/*
* VEEVA_PS_POPULATE_CYCLE_PLAN_FIELDS
* Veeva Professional Services
* Version 1, October 22, 2014
*
* Populate the Veeva Cycle Plan customer identifier fields for the account, address, and TSF objects.
* These fields are not populated for on going changes on submitted cycle plans without the batch process.
*
* For more information on custom fields, see:
* https://na1.vod309.com/doc/Default.htm#Veeva_CRM_Help/Veeva_CRM_Configuration/Cycle_Plans/Cycle_Plan_Targets_Custom_Fields.htm
*
* Monitor/Schedule batch apex at Setup > Monitoring > Scheduled Jobs. 
* Run on a nightly, weekly, monthly basis (whichever aligns with Cycle Plan, Account, Address, and TSF changes).
*
*/
    List<String> cptFields; 
    Map<String,List<String>> fldMap;

    global void execute(SchedulableContext sc) {
        VEEVA_PS_POPULATE_CYCLE_PLAN_FIELDS a = new VEEVA_PS_POPULATE_CYCLE_PLAN_FIELDS ();
        database.executebatch(a,100);
    }

    global VEEVA_PS_POPULATE_CYCLE_PLAN_FIELDS (){
        List<String> pre = new List<String>();
        pre.add('zvod_ADDRESS_');
        pre.add('zvod_ACCOUNT_');
        pre.add('zvod_TSF_');
        cptFields = getAccessibleFields('Cycle_Plan_Target_vod__c',pre);
        fldMap = new Map<String,List<String>>();
        for(String s : cptFields){
            String[] splt = s.split('_',3);
            System.debug('Adding ' + splt[1] + ' to map');
            String field = splt[2];
            String tName = null;
            if(splt[1].equals('ACCOUNT'))tName='Account';
            if(splt[1].equals('TSF'))tName='TSF_vod__c';
            if(splt[1].equals('ADDRESS'))tName='Address_vod__c';
            if(tName != null && !Schema.getGlobalDescribe().get(tName.toLowerCase()).getDescribe().Fields.getMap().containsKey(field)){
                field = field.substring(0,field.length()-3);
                System.debug('Modified field:' + field);
            }else{
                System.debug('Not modified field:' + field);
            }
            //if(field.equals('Name__c'))field = 'Name';
            //if(field.equals('IsPersonAccount__c'))field = 'IsPersonAccount';
            if(fldMap.containsKey(splt[1])){
                fldMap.get(splt[1]).add(field);
            }else{
                List<String> tmp = new List<String>();
                tmp.add(field);
                fldMap.put(splt[1],tmp);
            }
        }
        cptFields.add('Cycle_Plan_Account_vod__c');
        cptFields.add('Cycle_Plan_vod__r.Territory_vod__c');
        cptFields.add('id');
    }

    global Database.querylocator start(Database.BatchableContext BC){
        String query = 'Select ';
        query += joinList(cptFields,',');
        query += ' FROM Cycle_Plan_Target_vod__c WHERE Cycle_Plan_vod__r.active_vod__c = true';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC,List<sObject> cptList){
        Map<String,Account> actMap = new Map<String,Account>();
        List<String> actLst = new List<String>();
        Map<String,TSF_vod__c> tsfMap = new Map<String,TSF_vod__c>();
        List<String> tsfLst = new List<String>();
        Map<String,Address_vod__c> addMap = new Map<String,Address_vod__c>();
        for(sObject s : cptList){
            Cycle_Plan_Target_vod__c cpt = (Cycle_Plan_Target_vod__c)s;
            actLst.add(cpt.Cycle_Plan_Account_vod__c);
            tsfLst.add(cpt.Cycle_Plan_Account_vod__c + '__' + cpt.Cycle_Plan_vod__r.Territory_vod__c);
        }
        System.debug('Map keysize:' + fldMap.keyset().size());
        List<String> fldList = new List<String>();
        String q = '';
        if(fldMap.containsKey('TSF')){
            fldList.addAll(fldMap.get('TSF'));
            if(!contains(fldList,'External_Id_vod__c'))fldList.add('External_Id_vod__c');
            q = 'Select ' + joinList(fldList,',') + ' FROM TSF_vod__c WHERE External_Id_vod__c IN :tsfLst';
            for(sObject s : Database.query(q)){
                TSF_vod__c t = (TSF_vod__c)s;
                tsfMap.put(t.External_Id_vod__c,t);
            }
        }
        fldList = new List<String>();
        if(fldMap.containsKey('ADDRESS')){
            fldList.addAll(fldMap.get('ADDRESS'));
            if(!contains(fldList,'Account_vod__c'))fldList.add('Account_vod__c');
            q = 'Select ' + joinList(fldList,',') + ' FROM Address_vod__c WHERE Account_vod__c IN :actLst AND Primary_vod__c = true';
            for(sObject s : Database.query(q)){
                Address_vod__c t = (Address_vod__c)s;
                addMap.put(t.Account_vod__c,t);
            }
        }
        fldList = new List<String>();
        if(fldMap.containsKey('ACCOUNT')){
            fldList.addAll(fldMap.get('ACCOUNT'));
            if(!contains(fldList,'id'))fldList.add('id');
            q = 'Select ' + joinList(fldList,',') + ' FROM Account WHERE id IN :actLst';
            for(sObject s : Database.query(q)){
                Account t = (Account)s;
                actMap.put(t.id,t);
            }
        }
        List<sObject> upd = new List<sObject>();
        for(sObject s : cptList){
            Cycle_Plan_Target_vod__c cpt = (Cycle_Plan_Target_vod__c)s;
            //String tsfExtId = s.get('Cycle_Plan_Account_vod__c') + '__' + s.get('Cycle_Plan_vod__r.Territory_vod__c');
            String tsfExtId = s.get('Cycle_Plan_Account_vod__c') + '__' + cpt.Cycle_Plan_vod__r.Territory_vod__c;
            String actId = (String)(s.get('Cycle_Plan_Account_vod__c'));
            boolean change = false;
            
            fldList = fldMap.get('TSF');
            if (fldList != null && fldList.size() > 0) {
                for(String str : fldList){
                    String str2 = ending(str);
                    System.debug('Str:' + str);
                    System.debug('tsfExtId:' + tsfExtId + ':');
                    Object one = s.get('zvod_TSF_' + str2);
                    if(tsfMap.containsKey(tsfExtId)){
                        TSF_vod__c tTSF = tsfMap.get(tsfExtId);
                        Object two = tTSF.get(str);
                        if(one != two){
                            s.put('zvod_TSF_' + str2, tsfMap.get(tsfExtId).get(str) );
                            change = true;
                        }
                    }else{
                        System.debug('TSF does not exist:' + tsfExtId);
                    }
                } 
            }
            
            fldList = fldMap.get('ADDRESS');
            if (fldList != null && fldList.size() > 0) {
                for(String str : fldList){
                    String str2 = ending(str);
                    if(addMap.containsKey(actId)){
                        if(s.get('zvod_ADDRESS_' + str2) != addMap.get(actId).get(str)){
                            s.put('zvod_ADDRESS_' + str2, addMap.get(actId).get(str) );
                            change = true;
                        }
                    }else{
                        System.debug('No address for account:' + actId);
                    }
                }
            }
            
            fldList = fldMap.get('ACCOUNT');
            if (fldList != null && fldList.size() > 0) {
                for(String str : fldList){
                    String str2 = ending(str);
                    if(actMap.containsKey(actId)){
                        if(s.get('zvod_ACCOUNT_' + str2) != actMap.get(actId).get(str)){
                            s.put('zvod_ACCOUNT_' + str2, actMap.get(actId).get(str) );
                            change = true;
                        }
                    }else{
                        System.debug('Issue with account:' + actId);
                    }
                }
            }
            if(change)upd.add(s);
        }
        update upd;
    }
    
    private String ending(String str){
        if(!str.endsWith('__c')) str = str + '__c';
        return str;
    }
    
    global void finish(Database.BatchableContext BC){
        
    }
    
    public static boolean contains(List<String> lstIn, String str){
        boolean ret = false;
        for(String s : lstIn){
            if(s.equals(str)){
                ret = true;
                break;
            }
        }
        return ret;
    }
    
    public static String joinList(List<String> inLst, String sep){
        String ret = '';
        boolean strt = true;
        for(String s : inLst){
            if(!strt) ret += sep;
            strt = false;
            ret += s;
        }
        return ret;
    }
    
    public static List<String> getAccessibleFields(String objName,List<String> starts){
        List<String> fields = new List<String>();   
        Map<String,Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objName.toLowerCase()).getDescribe().Fields.getMap();         
        if(fieldMap != null){
            for(Schema.Sobjectfield ft : fieldMap.values()){
                Schema.DescribeFieldResult fd = ft.getDescribe();
                if(fd.isAccessible()){
                    for(String s : starts){
                        if(fd.getName().startsWith(s)){
                            fields.add(fd.getName());
                            break;
                        }
                    }
                }
            }
        }else{
            System.debug('FieldMap was null');
        }
        return fields;
    }
}
