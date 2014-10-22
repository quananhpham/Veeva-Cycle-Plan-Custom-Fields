Veeva-Cycle-Plan-Custom-Fields
==============================

Batch process to populate the Veeva Cycle Plan customer identifier fields for the account, address, and TSF objects.These fields are not populated for on going changes on submitted cycle plans without the batch process.

For more information on custom fields, see:
https://na1.vod309.com/doc/Default.htm#Veeva_CRM_Help/Veeva_CRM_Configuration/Cycle_Plans/Cycle_Plan_Targets_Custom_Fields.htm

Monitor/Schedule batch apex at Setup > Monitoring > Scheduled Jobs. 
Run on a nightly, weekly, monthly basis (whichever aligns with Cycle Plan, Account, Address, and TSF changes).
