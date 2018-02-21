set schema 'exeta';

/******************************************************************************/
/* INTERFACE TABLES                                                           */
/******************************************************************************/

alter table i_cond_node add constraint i_cond_node_fk_parent_id foreign key (parent_id) references i_cond_node;
alter table i_cond_node add constraint i_cond_node_fk_cond_node_type_id foreign key (cond_node_type_id) references r_cond_node_type;
alter table i_cond_node add constraint i_cond_node_fk_call_id foreign key (call_id) references i_call;
alter table i_cond_node add constraint i_cond_node_fk_stat_id foreign key (stat_id) references r_stat;

alter table i_call add constraint i_call_fk_cond_root_id foreign key (cond_root_id) references i_cond_node;
alter table i_call add constraint i_call_fk_task_id foreign key (task_id) references i_task;

alter table i_call_iden add constraint i_call_iden_fk_call_id foreign key (call_id) references i_call;

alter table i_call_feat add constraint i_call_feat_fk_call_id foreign key (call_id) references i_call;
 
alter table i_call_rule add constraint i_call_rule_fk_call_id foreign key (call_id) references i_call;
alter table i_call_rule add constraint i_call_rule_fk_rule_type_id foreign key (rule_type_id) references r_rule_type;

alter table i_call_rule_actn add constraint i_call_rule_actn_fk_call_rule_id foreign key (call_rule_id) references i_call_rule;
alter table i_call_rule_actn add constraint i_call_rule_actn_fk_actn_id foreign key (actn_id) references r_actn;
alter table i_call_rule_actn add constraint i_call_rule_actn_fk_time_unit_id foreign key (time_unit_id) references r_time_unit;

alter table i_call_node add constraint i_call_node_fk_parent_id foreign key (parent_id) references i_call_node;
alter table i_call_node add constraint i_call_node_fk_call_node_type_id foreign key (call_node_type_id) references r_call_node_type;
alter table i_call_node add constraint i_call_node_fk_call_id foreign key (call_id) references i_call;

alter table i_task add constraint i_task_fk_task_type_id foreign key (task_type_id) references r_task_type;
alter table i_task add constraint i_task_fk_call_root_id foreign key (call_root_id) references i_call_node;
alter table i_task add constraint i_task_fk_cond_root_id foreign key (cond_root_id) references i_cond_node;

alter table i_task_iden add constraint i_task_iden_fk_task_id foreign key (task_id) references i_task;
alter table i_task_iden add constraint i_task_iden_fk_iden_type_id foreign key (iden_type_id) references r_iden_type;

alter table i_task_feat add constraint i_task_feat_fk_task_id foreign key (task_id) references i_task;

alter table i_task_rule add constraint i_task_rule_fk_task_id foreign key (task_id) references i_task;
alter table i_task_rule add constraint i_task_rule_fk_rule_type_id foreign key (rule_type_id) references r_rule_type;

alter table i_task_rule_actn add constraint i_task_rule_actn_fk_task_rule_id foreign key (task_rule_id) references i_task_rule;
alter table i_task_rule_actn add constraint i_task_rule_actn_fk_actn_id foreign key (actn_id) references r_actn;
alter table i_task_rule_actn add constraint i_task_rule_actn_fk_time_unit_id foreign key (time_unit_id) references r_time_unit;

/******************************************************************************/
/* PERMANENT TABLES                                                           */
/******************************************************************************/

alter table p_call_node add constraint p_call_node_fk_parent_id foreign key (parent_id) references p_call_node;
alter table p_call_node add constraint p_call_node_fk_call_node_type_id foreign key (call_node_type_id) references r_call_node_type;

alter table p_cond_node add constraint p_cond_node_fk_parent_id foreign key (parent_id) references p_cond_node;
alter table p_cond_node add constraint p_cond_node_fk_cond_node_type_id foreign key (cond_node_type_id) references r_cond_node_type;

alter table p_inst add constraint p_inst_fk_exec_serv_id foreign key (exec_serv_id) references p_serv;
alter table p_inst add constraint p_inst_fk_gene_serv_id foreign key (gene_serv_id) references p_serv;
alter table p_inst add constraint p_inst_fk_sche_id foreign key (sche_id) references p_sche;
alter table p_inst add constraint p_inst_fk_call_leaf_id foreign key (call_leaf_id) references p_call_node;
alter table p_inst add constraint p_inst_fk_cond_root_id foreign key (cond_root_id) references p_cond_node;

\q

