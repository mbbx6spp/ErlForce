-module(sfdc_test).
-export([setup_initial_objects/3,login/0]).

-include_lib("eunit/include/eunit.hrl").

login()->
    application:start(inets),
    application:start(ssl),
    LoginInfo.

root_login()->
    application:start(inets),
    application:start(ssl),
    LoginInfo.


query_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
    sfdc:soql_query("select Id, Username, LastName, FirstName, Name, CompanyName, Division, Department, Title from User", SessionId, Endpoint).
    

send_single_email_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
    Messages=[[
	       {subject, "test1"},
	       {toAddress, "ian.g.brown@gmail.com"},
	       {plainTextBody,"helo1"}
	      ],
	      [
	       {subject, "test2"},
	       {toAddress, "x spam@hccp.org"},
	       {plainTextBody,"helo2"}
	      ],
	      [
	       {subject, "test2"},
	       {toAddress, "y spam@hccp.org"},
	       {plainTextBody,"helo2"}
	      ],
	      [
	       {subject, "test1"},
	       {toAddresses, ["igb@hccp.org", "spam@hccp.org"]},
	       {plainTextBody,"helo3"}
	      ]
	     ],
    [ok, {err, _}, {err, _}, ok]=sfdc:send_email(Messages, SessionId, Endpoint).
    

merge_test()->

    Account0=[ {"type", "string", "Account"},
	   {"Name", "string", "Merge Test Parent"}
	 ],

    Account1=[ {"type", "string", "Account"},
	   {"Name", "string", "Merge Test A"}
	 ],

    Account2=[ {"type", "string", "Account"},
	   {"Name", "string", "Merge Test B"}
	 ],
    
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),
    {ok, Id0}=sfdc:create(Account0, SessionId, Endpoint),
    {ok, Id1}=sfdc:create(Account1, SessionId, Endpoint),
    {ok, Id2}=sfdc:create(Account2, SessionId, Endpoint),
   
    Contact1=[ {"type", "string", "Contact"},
	   {"FirstName", "string", "FirstnameA"},
	   {"LastName", "string", "LastnameA"},
	   {"AccountId", "string", Id1}
	 ],
    Contact2=[ {"type", "string", "Contact"},
	   {"FirstName", "string", "FirstnameB"},
	   {"LastName", "string", "LastnameB"},
	   {"AccountId", "string", Id2}
	 ],

    {ok, _}=sfdc:create(Contact1, SessionId, Endpoint),
    {ok, _}=sfdc:create(Contact2, SessionId, Endpoint),
    
    sfdc:merge("Account", Id0, [Id1, Id2], SessionId, Endpoint),
    {ok,_}=sfdc:delete(Id0, SessionId, Endpoint).	      

search_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
    1=sfdc:search("FIND {*@force.hccp.org}", SessionId, Endpoint).

password_set_test()->
[{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),
    {err,"bad id eerla@force.hccp.org"}=sfdc:set_password("eerla@force.hccp.org", "dummypass", SessionId, Endpoint),
    ok=sfdc:set_password("005A0000001LCf1", "pa55w0rd3001", SessionId, Endpoint).


password_reset_test()->    
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),
    Password=sfdc:reset_password("005A0000001LCf1",  SessionId, Endpoint).



xml_to_sobject_conversion_test()->
    UserInfoSoap="<?xml version=\"1.0\" encoding=\"UTF-8\"?><soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"    xmlns=\"urn:partner.soap.sforce.com\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><soapenv:Body><getUserInfoResponse><result><accessibilityMode>false</accessibilityMode><currencySymbol>$</currencySymbol><orgDefaultCurrencyIsoCode>USD</orgDefaultCurrencyIsoCode><orgDisallowHtmlAttachments>false</orgDisallowHtmlAttachments><orgHasPersonAccounts>false</orgHasPersonAccounts><organizationId>00DA0000000aDfHMAU</organizationId><organizationMultiCurrency>false</organizationMultiCurrency><organizationName>HCCP</organizationName><profileId>00eA0000000tt1xIAA</profileId><roleId xsi:nil=\"true\"/><userDefaultCurrencyIsoCode xsi:nil=\"true\"/><userEmail>spam@hccp.org</userEmail><userFullName>Agner Erlang</userFullName><userId>005A0000001KH08IAG</userId><userLanguage>en_US</userLanguage><userLocale>en_US</userLocale><userName>eerla@force.hccp.org</userName><userTimeZone>America/Los_Angeles</userTimeZone><userType>Standard</userType><userUiSkin>Theme3</userUiSkin></result></getUserInfoResponse></soapenv:Body></soapenv:Envelope>",
    ExpectedUserInfo=get_user_info_sobject(),
    ExpectedUserInfo=sfdc:get_user_info_sobject_from_soap_response(UserInfoSoap).
    
add_note_functional_test()->
    CandidateId="a06A0000007fDIG",
    OwnerId="005A0000001KH08",
    Note=[ {"type", "string", "Note"},
	  {"ParentId", "string", CandidateId},
	  {"Title", "string", "My Test"},
	  {"Body", "string", "test content"},
	  {"OwnerId", "string", OwnerId}
	 ],
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),
    sfdc:create(Note, SessionId, Endpoint),
    sfdc:logout(SessionId, Endpoint).

delete_notes_functional_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),
    {IsDone, _, Size, Records}=sfdc:soql_query("select Id from Note where ParentId='a06A0000007fDIGIA2'", SessionId, Endpoint),
    F=fun(Record)->
	      [_,{"Id",_,Id},_]=Record,
	      sfdc:delete(Id, SessionId, Endpoint)	      
      end,
    Ids=lists:map(F, Records).
 
date_to_xsd_date_time_test()->
   sfdc:erlang_date_to_xsd_date_time(erlang:localtime()).
 
integer_pad_test()->  
    "02"=sfdc:integer_pad(2),
    "32"=sfdc:integer_pad(32),
    "00"=sfdc:integer_pad(0).
    

get_deleted_functional_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),
    1=sfdc:get_deleted("Note",{{2010,11,10},{23,43,0}}, {{2010,12,3},{0,0,0}}, SessionId, Endpoint),
    sfdc:logout(SessionId, Endpoint).

setup_initial_objects(Count, SessionId, Endpoint)->
    CandidateId="a06A0000007fDIG",
    OwnerId="005A0000001KH08",
    Note=[ {"type", "string", "Note"},
	  {"ParentId", "string", CandidateId},
	  {"Title", "string", lists:append("My Test", integer_to_list(Count))},
	  {"Body", "string", lists:append("test content", integer_to_list(Count))},
	  {"OwnerId", "string", OwnerId}
	 ],
    sfdc:create(Note, SessionId, Endpoint),
    case Count of
	1 -> ok;
	_ -> setup_initial_objects(Count-1, SessionId, Endpoint)
    end.
    
    


login_functional_test()->
     [{sessionId,SessionId}, {serverUrl, Endpoint}]=login().

happy_path_functional_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
    ExpectedUserInfo=get_user_info_sobject(),
    ExpectedUserInfo=sfdc:get_user_info(SessionId, Endpoint),
    ExpectedQueryResults=sfdc:soql_query("select Id, FolderId, IsDeleted, Name, DeveloperName, NamespacePrefix, ContentType, Type, IsPublic, BodyLength, Url, Description, Keywords, IsInternalUseOnly, AuthorId, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, IsBodySearchable from Document", SessionId, Endpoint),
    validate_query(ExpectedQueryResults, "true", 1, 23),
    SecondExpectedQueryResults=sfdc:soql_query("select Id, Username, LastName, FirstName, Name, CompanyName, Division, Department, Title from User", SessionId, Endpoint),
    validate_query(SecondExpectedQueryResults, "true", 5, 11),
    ExpectedQueryAllResults=sfdc:soql_query_all("select Id, Username, LastName, FirstName, Name, CompanyName, Division, Department, Title from User", SessionId, Endpoint),
    validate_query(ExpectedQueryAllResults, "true", 5, 11),
    {{_,_,_},{_,_,_}}=sfdc:get_server_timestamp(SessionId, Endpoint),
    [Activateable|_]=sfdc:describe_sobject("Note", SessionId, Endpoint),
    {"activateable","string","false"}=Activateable,
    SobjectDescriptions=sfdc:describe_sobjects(["Candidate__C","Note"], SessionId, Endpoint),
    2=length(SobjectDescriptions),
    [{"encoding",_,Encoding},{"maxBatchSize",_,MaxBatchSize}|_]=sfdc:describe_global(SessionId, Endpoint),
    "200"=MaxBatchSize,
    "UTF-8"=Encoding,
    [{"Label", Label},{"LogoUrl", LogoUrl},{"NameSpace",NameSpace},{"Selected", Selected},{"Tabs",FlattenedTabs}]=sfdc:describe_tabs(SessionId, Endpoint),
    %1=sfdc:describe_softphone_layout(SessionId, Endpoint).
    1=sfdc:describe_layout("Candidate__c",SessionId, Endpoint).

describe_data_category_groups_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),
    1=sfdc:describe_data_category_groups("Candidate__c", SessionId, Endpoint).

convert_lead_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),

    Lead=[ {"type", "string", "Lead"},
          {"LastName", "string", "Leaderson"},
	   {"FirstName", "string", "Lead"},
	   {"Company", "string", "LeadCo"},
	   {"Status", "string", "Open"}
         ],
    {ok, Id}=sfdc:create(Lead,SessionId,Endpoint),

    {err, "Converted objects can only be owned by users.  You must specify a user for the Owner field."}=sfdc:convert_lead(Id, "", "", "", "false", "false", "", "Qualified", "true", SessionId, Endpoint),
     [{"accountId", ReturnedAccountId},{"contactId", ReturnedContactId},{"leadId", ReturnedLeadId},{"opportunityId", ReturnedOpportunityId}]=sfdc:convert_lead(Id, "", "", "005A0000000KRps", "false", "true", "", "Qualified", "true", SessionId, Endpoint).


process_submit_test()->
    
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
    
    CandidateA=[
		{"type", "string", "Candidate__c"},
		{"First_Name__c", "string", "Ian"},
		{"Last_Name__c", "string", "Brown"}
	       ],
    
    {ok, IdA}=sfdc:create(CandidateA, SessionId, Endpoint),
    {err, "No applicable approval process found."}=sfdc:process_submit(IdA, "testing", [],SessionId, Endpoint),
    {ok, IdA}=sfdc:delete(IdA, SessionId, Endpoint),
    CandidateB=[
		{"type", "string", "Candidate__c"},
		{"First_Name__c", "string", "Foo"},
		{"Last_Name__c", "string", "Foo"}
	      ],
    {ok, IdB}=sfdc:create(CandidateB, SessionId, Endpoint),
    [{"entityId",_},
                     {"instanceId",_},
                     {"instanceStatus",_},
                     {"success","true"},
                     {"newWorkitemIds",[_]},
                     {"actorIds",[_]}]=sfdc:process_submit(IdB, "testing", ["005A0000000KRps"],SessionId, Endpoint),
    {ok, IdB}=sfdc:delete(IdB, SessionId, Endpoint).
 

get_process_response_test()->
    Results=[{actorIds,[],["ActorId1"]},
	     {entityId,[],["EntityId"]},
	     {instanceId,[],["InstanceId"]},
	     {instanceStatus,[],["InstanceStatus"]},
	     {newWorkitemIds,[],["NewWorkItemId1"]},
	     {success,[],["true"]}],
    [{"entityId","EntityId"},
     {"instanceId","InstanceId"},
     {"instanceStatus","InstanceStatus"},
     {"success","true"},
     {"newWorkitemIds",["NewWorkItemId1"]},
     {"actorIds",["ActorId1"]}]=sfdc:get_process_response(Results, [],[],[]).


invalidate_sessions_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
    [{sessionId,SessionId2}, {serverUrl, _}]=root_login(),
    ok=sfdc:invalidate_sessions([SessionId2],SessionId, Endpoint),
    {err,  "The session is invalid or logged out."}=sfdc:invalidate_sessions([SessionId2],SessionId, Endpoint).


empty_recycle_bin_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
    
    CandidateA=[
		{"type", "string", "Candidate__c"},
		{"First_Name__c", "string", "IanRecycleBinA"},
		{"Last_Name__c", "string", "BrownRecycleBinA"}
	       ],
    
    {ok, IdA}=sfdc:create(CandidateA, SessionId, Endpoint),
    {ok, IdA}=sfdc:delete(IdA, SessionId, Endpoint),

    CandidateB=[
		{"type", "string", "Candidate__c"},
		{"First_Name__c", "string", "FooRecycleBinB"},
		{"Last_Name__c", "string", "FooRecycleBinB"}
	      ],
    {ok, IdB}=sfdc:create(CandidateB, SessionId, Endpoint),
    {ok, IdB}=sfdc:delete(IdB, SessionId, Endpoint),
    [{ok,IdA},{ok,IdB}]=sfdc:empty_recycle_bin([IdA,IdB], SessionId, Endpoint),
    [{err,_},{err,_}]=sfdc:empty_recycle_bin(["foo","bar"], SessionId, Endpoint).


undelete_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
    
    CandidateA=[
		{"type", "string", "Candidate__c"},
		{"First_Name__c", "string", "IanRecycleBinA"},
		{"Last_Name__c", "string", "BrownRecycleBinA"}
	       ],
    
    {ok, IdA}=sfdc:create(CandidateA, SessionId, Endpoint),
    {ok, IdA}=sfdc:delete(IdA, SessionId, Endpoint),

    CandidateB=[
		{"type", "string", "Candidate__c"},
		{"First_Name__c", "string", "FooRecycleBinB"},
		{"Last_Name__c", "string", "FooRecycleBinB"}
	      ],
    {ok, IdB}=sfdc:create(CandidateB, SessionId, Endpoint),
    {ok, IdB}=sfdc:delete(IdB, SessionId, Endpoint),
    [{ok,IdA},{ok,IdB}]=sfdc:undelete([IdA,IdB], SessionId, Endpoint),
    [{err,_},{err,_}]=sfdc:undelete(["foo","bar"], SessionId, Endpoint).

retrieve_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
        CandidateA=[
		{"type", "string", "Candidate__c"},
		{"First_Name__c", "string", "IanRetrieveA"},
		{"Last_Name__c", "string", "BrownRetrieveA"}
	       ],
    {ok, IdA}=sfdc:create(CandidateA, SessionId, Endpoint),


    CandidateB=[
		{"type", "string", "Candidate__c"},
		{"First_Name__c", "string", "FooRetrieveB"},
		{"Last_Name__c", "string", "FooRetrieveB"}
	       ],
    {ok, IdB}=sfdc:create(CandidateB, SessionId, Endpoint),
    
    [
     [{"type","string","Candidate__c"},
      {"Id","string",_},
      {"First_Name__c","string","IanRetrieveA"},
      {"Last_Name__c","string","BrownRetrieveA"},
      {"Id","string",_}],
     [{"type","string","Candidate__c"},
      {"Id","string",_},
      {"First_Name__c","string","FooRetrieveB"},
      {"Last_Name__c","string","FooRetrieveB"},
      {"Id","string",_}]     
    ]=sfdc:retrieve(["First_Name__c", "Last_Name__c"], "Candidate__c", [IdA, IdB], SessionId, Endpoint),
   {err, _}= sfdc:retrieve(["First_Name__c", "Last_Name__c"], "Candidate__c", ["xxx"], SessionId, Endpoint).


validate_query(Results, ExpectedIsDone, ExpectedSize, ExpectedNumberOfAttributesPerRecord)->
    {IsDone, _, Size, Records}=Results,
    ExpectedIsDone=IsDone,
    ExpectedSize=Size,
    [FirstRecord|_]=Records,
    ExpectedNumberOfAttributesPerRecord=length(FirstRecord).    


%erlang_object_query_functional_test()->
%    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
%    {IsDone, _, Size, Records}=sfdc:soql_query("select Id, OwnerId, MyDescription__c from ErlangTestObject__c", SessionId, Endpoint).

upsert_test()->
     [{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),
    CandidateId="a06A0000007fDIG",
    OwnerId="005A0000001KH08",
    {Megaseconds,Seconds,Microseconds} = erlang:now(),
    Note1=[ {"type", "string", "Note"},
	    {"ParentId", "string", CandidateId},
	    {"Title", "string", lists:append(["My Upsert Test", integer_to_list(Megaseconds),integer_to_list(Seconds),integer_to_list(Microseconds) ])},
	    {"Body", "string", lists:append(["test content", integer_to_list(Megaseconds),integer_to_list(Seconds),integer_to_list(Microseconds) ])},
	    {"OwnerId", "string", OwnerId}
	   ],
    Note2=[ {"type", "string", "Note"},
	    {"ParentId", "string", CandidateId},
	    {"Title", "string", lists:append(["My Upsert Test 2", integer_to_list(Megaseconds),integer_to_list(Seconds),integer_to_list(Microseconds) ])},
	    {"Body", "string", lists:append(["test content 2", integer_to_list(Megaseconds),integer_to_list(Seconds),integer_to_list(Microseconds) ])},
	    {"OwnerId", "string", OwnerId}
	   ],
   Results=sfdc:upsert("Id",[Note1, Note2], SessionId, Endpoint),    
    2=length(Results),
    [Result1, Result2]=Results,
    [{"created","true"},{"id",Id},{"success","true"}]=Result1,
    [{"created","true"},{"id",_},{"success","true"}]=Result2,
    Note3=[ {"Id", "string", Id},
	    {"type", "string", "Note"},
	    {"ParentId", "string", CandidateId},
	    {"Title", "string", lists:append(["My Upsert Test 3", integer_to_list(Megaseconds),integer_to_list(Seconds),integer_to_list(Microseconds) ])},
	    {"Body", "string", lists:append(["test content 3", integer_to_list(Megaseconds),integer_to_list(Seconds),integer_to_list(Microseconds) ])},
	    {"OwnerId", "string", OwnerId}
	   ],
    UpdateResult=sfdc:upsert("Id",[Note3], SessionId, Endpoint),
    3=length(UpdateResult),
    [{"created","false"},{"id",Id},{"success","true"}]=UpdateResult,
    2=length(delete_notes_functional_test()).


update_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=login(),
    Id="005A0000001KH08",
    UpdateStatusSobject=[
			 {"type", "string", "User"},
			 {"Id", "string", Id},
			 {"CurrentStatus", "string", "Helloa"}
			],
    BadUpdateStatusSobject=[
			    {"sId", "string", "xxx"},
			 {"CurrentStatus", "string", "Hello"}
			],
    
    {ok, _}=sfdc:update(UpdateStatusSobject, SessionId, Endpoint),
     {err, Reason}=sfdc:update(BadUpdateStatusSobject, SessionId, Endpoint).

get_updated_test()->
    [{sessionId,SessionId}, {serverUrl, Endpoint}]=root_login(),
    {{ids,_},{lastDateCovered, _}}=sfdc:get_updated("Candidate__c", {{2011,1,1},{0,0,0}}, erlang:localtime(),SessionId, Endpoint),
    {{ids,_},{lastDateCovered, _}}=sfdc:get_updated("Candidate__c", erlang:localtime(), erlang:localtime(),SessionId, Endpoint).

get_user_info_sobject()->
    [{"accessibilityMode","string","false"},
     {"currencySymbol","string","$"},
     {"orgDefaultCurrencyIsoCode","string","USD"},
     {"orgDisallowHtmlAttachments","string","false"},
     {"orgHasPersonAccounts","string","false"},
     {"organizationId","string","00DA0000000aDfHMAU"},
     {"organizationMultiCurrency","string","false"},
     {"organizationName","string","HCCP"},
     {"profileId","string","00eA0000000tt1xIAA"},
     {"roleId","string",[]},
     {"userDefaultCurrencyIsoCode","string",[]},
     {"userEmail","string","spam@hccp.org"},
     {"userFullName","string","Agner Erlang"},
     {"userId", "string", "005A0000001KH08IAG"},
     {"userLanguage", "string", "en_US"},
     {"userLocale", "string", "en_US"},
     {"userName", "string", "eerla@force.hccp.org"},
     {"userTimeZone", "string", "America/Los_Angeles"},
     {"userType", "string", "Standard"},
     {"userUiSkin", "string", "Theme3"}].


