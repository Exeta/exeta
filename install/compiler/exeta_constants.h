// task_types
#define task_types_call            0
#define task_types_execute         1
#define task_types_generate_once   2
#define task_types_generate_always 3

// rule_types
#define rule_types_failed    0
#define rule_types_succeeded 1
#define rule_types_skipped   2

// actions
#define actions_succeed       0
#define actions_skip          1
#define actions_suspend       2
#define actions_fail_caller   3
#define actions_submit_same   4
#define actions_submit_next   5
#define actions_submit_future 6

// time_units
#define time_units_s 0
#define time_units_m 1
#define time_units_h 2

// statuses
#define statuses_submitted 0
#define statuses_running   1
#define statuses_failed    2
#define statuses_succeeded 3
#define statuses_skipped   4
#define statuses_suspended 5

// call_node_types
#define call_node_types_in_sequence 0
#define call_node_types_in_parallel 1
#define call_node_types_atom        2

// cond_node_types
#define cond_node_types_and  0
#define cond_node_types_or   1
#define cond_node_types_atom 2

// identifier_types
#define identifier_types_ordinary 0
#define identifier_types_list     1
#define identifier_types_member   2
