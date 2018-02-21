/******************************************************************************/
/* Exeta grammar                                                              */
/******************************************************************************/

%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "exeta_constants.h"

int yylex(); 
int yyerror(const char *p) { fprintf(stderr, "Error!\n"); };

FILE
    *f
,   *f_language
,   *f_server
,   *f_schedule
,   *f_schedule_node
,   *f_task
,   *f_call
,   *f_identifier_name
,   *f_identifier_value
,   *f_feature
,   *f_rule
,   *f_call_node
,   *f_condition_node
;

int
    id = 0
,   language_id=0
,   server_id=0
,   schedule_id=0
,   task_id = 0
,   call_id
,   parent_call_id
,   rule_id = 0
,   call_node_id = 0
,   condition_node_id = 0
,   identifier_type
,   call_leaf
,   call_leaf_call_id
,   schedule_position
,   schedule_node_type
,   identifier_name_position
,   identifier_value_position
,   feature_position
,   failed_rule_position
,   i
;

char
    object_type
;

%}

%union {
    char *str;
    int  num;
}

%token server
%token schedule
%token star
%token minus
%token task
%token with
%token equal
%token comma
%token when
%token submitted
%token running
%token failed
%token suspended
%token succeeded
%token skipped
%token submit
%token same
%token next
%token future
%token succeed
%token skip
%token fail
%token run
%token caller
%token suspend
%token after
%token s
%token m
%token h
%token times
%token then
%token call
%token par
%token seq
%token execute
%token generate
%token always
%token once
%token twice
%token lparenthesis
%token rparenthesis
%token colon
%token and
%token or
%token semicolon

%token <str> TASK
%token <str> CALL
%token <str> FEATURE
%token <str> VALUE
%token <str> NUMBER
%token <num> MINUTE
%token <num> HOUR
%token <num> DAYOFM
%token <num> MONTH
%token <num> DAYOFW

%right par
%right seq
%right or
%right and

%start Exeta

%%

Exeta: Item | Exeta Item ;

Item: Server | Schedule | Task ;

Server:
    server FEATURE[L]
    {   fprintf(f_language, "%d\a%s\n", ++language_id, $<str>[L])
    ;   }
    ServerList
    semicolon
;
ServerList: ServerName | ServerList ServerName
;
ServerName:
    FEATURE[S]
    {   fprintf(f_server, "%d\a%s\a%d\n", ++server_id, $<str>[S], language_id)
    ;   }
;

Schedule:
    schedule FEATURE[S]
    {   fprintf(f_schedule, "%d\a%s\n", ++schedule_id, $<str>[S])
    ;   schedule_position = 0
    ;   }
    ScheduleList
    semicolon
;

ScheduleList:
    ScheduleItem
|   ScheduleList
    or
    {   schedule_position++
    ;   }
    ScheduleItem
;

ScheduleItem: Minutes and Hours and { schedule_node_type = 3; } DaysOfM and { schedule_node_type = 4; } DaysOfM and Months and DaysOfW ;

Minutes:
    MinutesList
|   star
    {   for (i=0;i<60;i++) fprintf(f_schedule_node, "%d\a%d\a1\a%d\n", schedule_id, schedule_position, i)
    ;   }
;
MinutesList: MinutesItem | MinutesList comma MinutesItem
;
MinutesItem:
    MINUTE[X]
    {   fprintf(f_schedule_node, "%d\a%d\a1\a%d\n", schedule_id, schedule_position, $<num>[X])
    ;   }
|   MINUTE[X] minus MINUTE[Y]
    {   for (i=$<num>[X];i<=$<num>[Y];i++) fprintf(f_schedule_node, "%d\a%d\a1\a%d\n", schedule_id, schedule_position, i)
    ;   }
;

Hours:
    HoursList
|   star
    {   for (i=0;i<24;i++) fprintf(f_schedule_node, "%d\a%d\a2\a%d\n", schedule_id, schedule_position, i)
    ;   }
;
HoursList: HoursItem | HoursList comma HoursItem
;
HoursItem:
    HOUR[X]
    {   fprintf(f_schedule_node, "%d\a%d\a2\a%d\n", schedule_id, schedule_position, $<num>[X])
    ;   }
|   HOUR[X] minus HOUR[Y]
    {   for (i=$<num>[X];i<=$<num>[Y];i++) fprintf(f_schedule_node, "%d\a%d\a2\a%d\n", schedule_id, schedule_position, i)
    ;   }
;

DaysOfM:
    DaysOfMList
|   star
    {   for (i=1;i<32;i++) fprintf(f_schedule_node, "%d\a%d\a%d\a%d\n", schedule_id, schedule_position, schedule_node_type, i)
    ;   }
;
DaysOfMList: DaysOfMItem | DaysOfMList comma DaysOfMItem
;
DaysOfMItem:
    DAYOFM[X]
    {   fprintf(f_schedule_node, "%d\a%d\a%d\a%d\n", schedule_id, schedule_position, schedule_node_type, $<num>[X])
    ;   }
|   DAYOFM[X] minus DAYOFM[Y]
    {   for (i=$<num>[X];i<=$<num>[Y];i++) fprintf(f_schedule_node, "%d\a%d\a%d\a%d\n", schedule_id, schedule_position, schedule_node_type, i)
    ;   }
;

Months:
    MonthsList
|   star
    {   for (i=1;i<13;i++) fprintf(f_schedule_node, "%d\a%d\a5\a%d\n", schedule_id, schedule_position, i)
    ;   }
;
MonthsList: MonthsItem | MonthsList comma MonthsItem
;
MonthsItem:
    MONTH[X]
    {   fprintf(f_schedule_node, "%d\a%d\a5\a%d\n", schedule_id, schedule_position, $<num>[X])
    ;   }
|   MONTH[X] minus MONTH[Y]
    {   for (i=$<num>[X];i<=$<num>[Y];i++) fprintf(f_schedule_node, "%d\a%d\a5\a%d\n", schedule_id, schedule_position, i)
    ;   }
;

DaysOfW:
    DaysOfWList
|   star
    {   for (i=1;i<8;i++) fprintf(f_schedule_node, "%d\a%d\a6\a%d\n", schedule_id, schedule_position, i)
    ;   }
;
DaysOfWList: DaysOfWItem | DaysOfWList comma DaysOfWItem
;
DaysOfWItem:
    DAYOFW[X]
    {   fprintf(f_schedule_node, "%d\a%d\a6\a%d\n", schedule_id, schedule_position, $<num>[X])
    ;   }
|   DAYOFW[X] minus DAYOFW[Y]
    {   for (i=$<num>[X];i<=$<num>[Y];i++) fprintf(f_schedule_node, "%d\a%d\a6\a%d\n", schedule_id, schedule_position, i)
    ;   }
;

Task:
    task TASK[T]
    {   fprintf(f_task, "%d\a%s\a", task_id, $<str>[T])
    ;   call_id = 0
    ;   identifier_type = identifier_types_ordinary
    ;   identifier_name_position = 0
    ;   object_type = 'T'
    ;   }
    IdentifierNameClause
    FeatureClause
    RuleClause
    Body
    semicolon
    {   task_id++
    ;   }
;

IdentifierNameClause:
    /* empty */
|   IdentifierNames
    {   fprintf(f_identifier_name, "%d\n", identifier_type)
    ;   }
|   IdentifierNames
    colon
    {   fprintf(f_identifier_name, "%d\n", identifier_types_list)
    ;   identifier_type = identifier_types_member
    ;   }
    IdentifierNames
    {   fprintf(f_identifier_name, "%d\n", identifier_type)
    ;   }
;

IdentifierNames:
    IdentifierName
|   IdentifierNames
    {   fprintf(f_identifier_name, "%d\n", identifier_type)
    ;   }
    IdentifierName
;

IdentifierName:
    FEATURE[F]
    {   fprintf(f_identifier_name, "%d\a%d\a%s\a", task_id, identifier_name_position++, $<str>[F])
    ;   }
;

FeatureClause:
    /* empty */
|   with { feature_position = 0; } Features
;

Features:
    Feature
|   Features
    comma
    Feature
;

Feature:
    FEATURE[F]
    {   f = f_feature
    ;   if (object_type == 'C') fprintf(f, "%d", call_id)
    ;   fprintf(f, "\a%d\a%d\a%s\a", task_id, feature_position++, $<str>[F])
    ;   }
    equal
    Value
    {   fprintf(f_feature, "\n")
    ;   }
;

Value:
    AtomicValue
|   ListValue
;

AtomicValue:
    VALUE[V]
    {   fprintf(f, "%s", $<str>[V])
    ;   }
;

ListValue:
    lparenthesis
    {   fprintf(f, "(")
    ;   }
    AtomicValues
    rparenthesis
    {   fprintf(f, ")")
    ;   }
;

AtomicValues:
    AtomicValue
|   AtomicValues
    {   fprintf(f, " ")
    ;   }
    AtomicValue
;

IdentifierValueClause:
    /* empty */
|   { identifier_value_position = 0; } IdentifierValues
;

IdentifierValues:
    IdentifierValue
|   IdentifierValues
    IdentifierValue
;

IdentifierValue:
    {   f = f_identifier_value
    ;   fprintf(f, "%d\a%d\a%d\a", task_id, call_id, identifier_value_position++)
    ;   }
    Value
    {   fprintf(f_identifier_value, "\n")
    ;   }
;

Body:
    execute
    {   fprintf(f_task, "%d\n", task_types_execute)
    ;   }
|
    generate once
    {   fprintf(f_task, "%d\n", task_types_generate_once)
    ;   }
|
    generate always
    {   fprintf(f_task, "%d\n", task_types_generate_always)
    ;   }
|
    call
    {   call_node_id = 0
    ;   }
    Call
    {   fprintf(f_call_node, "\a0\n")
    ;   fprintf(f_task, "%d\n", task_types_call)
    ;   }
;

Call:
    CALL[C]
    {   fprintf(f_call, "%d\a%d\a%s\n", task_id, call_id, $<str>[C])
    ;   fprintf(f_call_node, "%d\a%d\a%d\a%d\a", task_id, call_node_id++, call_node_types_atom, call_id)
    ;   object_type = 'C'
    ;   }
    IdentifierValueClause
    FeatureClause
    {   parent_call_id = call_id++
    ;   }
    RuleClause
|
    Call
    seq
    {   fprintf(f_call_node, "%d\a0\n", $<num>$ = call_node_id++)
    ;   }[CallRootId]
    Call
    {   fprintf(f_call_node, "%d\a1\n", $<num>[CallRootId])
    ;   fprintf(f_call_node, "%d\a%d\a%d\a\a", task_id, $<num>[CallRootId], call_node_types_in_sequence)
    ;   }
|
    Call
    par
    {   fprintf(f_call_node, "%d\a0\n", $<num>$ = call_node_id++)
    ;   }[CallRootId]
    Call
    {   fprintf(f_call_node, "%d\a1\n", $<num>[CallRootId])
    ;   fprintf(f_call_node, "%d\a%d\a%d\a\a", task_id, $<num>[CallRootId], call_node_types_in_parallel)
    ;   }
|
    lparenthesis
    Call[CallRootId]
    rparenthesis
;
Condition:
    CALL[C]
    {   fprintf(f_call, "%d\a%d\a%s\n", task_id, call_id, $<str>[C])
    ;   if (object_type == 'C') fprintf(f_condition_node, "%d", parent_call_id);
    ;   fprintf(f_condition_node, "\a%d\a%d\a%d\a%d\a", task_id, condition_node_id++, cond_node_types_atom, call_id)
    ;   }
    IdentifierValueClause
    Status
    {   fprintf(f_condition_node, "\a")
    ;   call_id++
    ;   }
|   
    Condition
    and
    {   fprintf(f_condition_node, "%d\a0\n", $<num>$ = condition_node_id++)
    ;   }[ConditionRootId]
    Condition
    {   fprintf(f_condition_node, "%d\a1\n", $<num>[ConditionRootId])
    ;   if (object_type == 'C') fprintf(f_condition_node, "%d", parent_call_id)
    ;   fprintf(f_condition_node, "\a%d\a%d\a%d\a\a\a\a\a", task_id, $<num>[ConditionRootId], cond_node_types_and)
    ;   }
|
    Condition
    or
    {   fprintf(f_condition_node, "%d\a0\n", $<num>$ = condition_node_id++)
    ;   }[ConditionRootId]
    Condition
    {   fprintf(f_condition_node, "%d\a1\n", $<num>[ConditionRootId])
    ;   if (object_type == 'C') fprintf(f_condition_node, "%d", parent_call_id)
    ;   fprintf(f_condition_node, "\a%d\a%d\a%d\a\a\a\a\a", task_id, $<num>[ConditionRootId], cond_node_types_or)
    ;   }
|
    lparenthesis
    Condition[ConditionRootId]
    rparenthesis
;
Status:
    submitted { fprintf(f_condition_node, "%d",     statuses_submitted); } TimeClause
|   running   { fprintf(f_condition_node, "%d",     statuses_running  ); } TimeClause
|   failed    { fprintf(f_condition_node, "%d",     statuses_failed   ); } TimeClause
|   suspended { fprintf(f_condition_node, "%d",     statuses_suspended); } TimeClause
|   skipped   { fprintf(f_condition_node, "%d\a\a", statuses_skipped  ); }
|   succeeded { fprintf(f_condition_node, "%d\a\a", statuses_succeeded); }
;

TimeClause:
    /* empty */
    {   fprintf(f_condition_node, "\a\a")
    ;   }
|   Time[T] TimeUnit[TU]
    {   fprintf(f_condition_node, "%d\a%d\a", $<num>[T], $<num>[TU])
    ;   }
;
Time:
    NUMBER[N] { $<num>$ = $<num>[N]; }
;
TimeUnit:
    s { $<num>$ = time_units_s; }
|   m { $<num>$ = time_units_m; }
|   h { $<num>$ = time_units_h; }
;

RuleClause:
    { failed_rule_position = 0; } Rules
;
Rules:
    RunRule FailedSucceededSkippedRule
|   FailedSucceededSkippedRule
;
FailedSucceededSkippedRule:
    FailedRule SucceededSkippedRule
|   SucceededSkippedRule
;
SucceededSkippedRule:
    SucceededRule SkippedRule
|   SkippedRule
;
RunRule:
    run
    when
    {   condition_node_id = 0
    ;   }
    Condition
    {   fprintf(f_condition_node, "\a0\n")
    ;   }
;
FailedRule:
    succeed                               when failed  { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_failed, failed_rule_position,   actions_succeed); }
|   skip                                  when failed  { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_failed, failed_rule_position,   actions_skip); }
|   suspend                               when failed  { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_failed, failed_rule_position,   actions_suspend); }
|   fail caller                           when failed  { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_failed, failed_rule_position,   actions_fail_caller); }
|   submit same                           when failed  { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_failed, failed_rule_position,   actions_submit_same); }
|   submit same after Time[T] TimeUnit[U] when failed  { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a%d\a%d\a\n",   task_id, rule_types_failed, failed_rule_position,   actions_submit_same, $<num>[T], $<num>[U]); }
|
    fail caller                           Iteration[I] { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a%d\n",     task_id, rule_types_failed, failed_rule_position++, actions_fail_caller,            $<num>[I]); }            then FailedRule
|   submit same                           Iteration[I] { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a%d\n",     task_id, rule_types_failed, failed_rule_position++, actions_submit_same,            $<num>[I]); }            then FailedRule
|   submit same after Time[T] TimeUnit[U] Iteration[I] { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a%d\a%d\a%d\n", task_id, rule_types_failed, failed_rule_position++, actions_submit_same, $<num>[T], $<num>[U], $<num>[I]); } then FailedRule
;
SucceededRule:
    submit same   when succeeded                       { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_succeeded, 0, actions_submit_same); }
|   submit next   when succeeded                       { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_succeeded, 0, actions_submit_next); }
|   submit future when succeeded                       { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_succeeded, 0, actions_submit_future); }
;
SkippedRule:
    /* empty */
|   submit same   when skipped                         { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_skipped, 0, actions_submit_same); }
|   submit next   when skipped                         { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_skipped, 0, actions_submit_next); }
|   submit future when skipped                         { if (object_type == 'C') fprintf(f_rule, "%d", parent_call_id); fprintf(f_rule, "\a%d\a%d\a%d\a%d\a\a\a\n",       task_id, rule_types_skipped, 0, actions_submit_future); }
;
Iteration:
    once      { $<num>$ = 1; }
|   twice     { $<num>$ = 2; }
|   NUMBER[N] { $<num>$ = $<num>[N]; } times
;

%%

int main(int argc, const char **argv)
{
    //extern int yydebug;
    //yydebug = 1;
    
    f_language         = fopen("./language.dsv", "w");
    f_server           = fopen("./server.dsv", "w");
    f_schedule         = fopen("./schedule.dsv", "w");
    f_schedule_node    = fopen("./schedule_node.dsv", "w");
    f_task             = fopen("./task.dsv", "w");
    f_call             = fopen("./call.dsv", "w");
    f_identifier_name  = fopen("./identifier_name.dsv", "w");
    f_identifier_value = fopen("./identifier_value.dsv", "w");
    f_feature          = fopen("./feature.dsv", "w");
    f_rule             = fopen("./rule.dsv", "w");
    f_call_node        = fopen("./call_node.dsv", "w");
    f_condition_node   = fopen("./condition_node.dsv", "w");
    
    yyparse();

    fclose(f_language);
    fclose(f_server);
    fclose(f_schedule);
    fclose(f_schedule_node);
    fclose(f_task);
    fclose(f_call);
    fclose(f_identifier_name);
    fclose(f_identifier_value);
    fclose(f_feature);
    fclose(f_rule);
    fclose(f_call_node);
    fclose(f_condition_node);

    return 0;
}
