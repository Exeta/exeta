set schema 'exeta';

/******************************************************************************/
/* INTERFACE TABLES                                                           */
/******************************************************************************/

alter table i_cond_node drop constraint i_cond_node_fk_parent_id;
alter table i_cond_node drop constraint i_cond_node_fk_cond_node_type_id;
alter table i_cond_node drop constraint i_cond_node_fk_call_id;
alter table i_cond_node drop constraint i_cond_node_fk_stat_id;

alter table i_call drop constraint i_call_fk_cond_root_id;
alter table i_call drop constraint i_call_fk_task_id;

alter table i_call_iden drop constraint i_call_iden_fk_call_id;

alter table i_call_feat drop constraint i_call_feat_fk_call_id;

alter table i_call_rule drop constraint i_call_rule_fk_call_id;
alter table i_call_rule drop constraint i_call_rule_fk_rule_type_id;

alter table i_call_rule_actn drop constraint i_call_rule_actn_fk_call_rule_id;
alter table i_call_rule_actn drop constraint i_call_rule_actn_fk_actn_id;
alter table i_call_rule_actn drop constraint i_call_rule_actn_fk_time_unit_id;

alter table i_call_node drop constraint i_call_node_fk_parent_id;
alter table i_call_node drop constraint i_call_node_fk_call_node_type_id;
alter table i_call_node drop constraint i_call_node_fk_call_id;

alter table i_task drop constraint i_task_fk_task_type_id;
alter table i_task drop constraint i_task_fk_call_root_id;
alter table i_task drop constraint i_task_fk_cond_root_id;

alter table i_task_iden drop constraint i_task_iden_fk_task_id;
alter table i_task_iden drop constraint i_task_iden_fk_iden_type_id;

alter table i_task_feat drop constraint i_task_feat_fk_task_id;

alter table i_task_rule drop constraint i_task_rule_fk_task_id;
alter table i_task_rule drop constraint i_task_rule_fk_rule_type_id;

alter table i_task_rule_actn drop constraint i_task_rule_actn_fk_task_rule_id;
alter table i_task_rule_actn drop constraint i_task_rule_actn_fk_actn_id;
alter table i_task_rule_actn drop constraint i_task_rule_actn_fk_time_unit_id;

/******************************************************************************/
/* PERMANENT TABLES                                                           */
/******************************************************************************/

alter table p_call_node drop constraint p_call_node_fk_parent_id;
alter table p_call_node drop constraint p_call_node_fk_call_node_type_id;

alter table p_cond_node drop constraint p_cond_node_fk_parent_id;
alter table p_cond_node drop constraint p_cond_node_fk_cond_node_type_id;

alter table p_inst drop constraint p_inst_fk_exec_serv_id;
alter table p_inst drop constraint p_inst_fk_gene_serv_id;
alter table p_inst drop constraint p_inst_fk_sche_id;
alter table p_inst drop constraint p_inst_fk_call_leaf_id;
alter table p_inst drop constraint p_inst_fk_cond_root_id;

\q

