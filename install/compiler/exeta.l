/* Exeta scanner */

%option case-insensitive
%option noyywrap
%x Server00 Server01 Schedule00 Schedule01 Schedule02 Schedule03 Schedule04 Schedule05 Schedule06 Task Call Feature Value Number

%{
#include "exeta.tab.h"
%}

TASK    [a-zA-Z][a-zA-Z0-9_.]*
FEATURE [a-zA-Z][a-zA-Z0-9_]*
FVALUE  \$\{{FEATURE}\}
CALL    [a-zA-Z]([a-zA-Z0-9_.]|{FVALUE})*
NUMBER  [0-9]+
MINUTE  [0-5][0-9]|[0-9]
HOUR    [0-9]|(0|1)[0-9]|2[0-3]
DAYOFM  [1-9]|0[1-9]|[12][0-9]|3[01]
MONTH   [0-9]|0[1-9]|1[012]
DAYOFW  [1-7]|0[1-7]
VALUE   ('([^'])*')|(\"([^\"\\]|\\.)*\")|(\$'([^'\\]|\\.)*')|(\$\"([^\"\\]|\\.)*\")|(([^ \t\n,;()\\]|\\.)+)
COMMENT #.*\n
%%

<INITIAL>"server"     { fprintf(stderr, "server");                                        BEGIN(Server00);   return server; }
<Server00>{FEATURE}   { fprintf(stderr, "[LNG:%s]", yytext); yylval.str = strdup(yytext); BEGIN(Server01);   return FEATURE; }
<Server01>{FEATURE}   { fprintf(stderr, "[SRV:%s]", yytext); yylval.str = strdup(yytext);                    return FEATURE; }

<INITIAL>"schedule"   { fprintf(stderr, "schedule");                                      BEGIN(Schedule00); return schedule; }
<Schedule00>{FEATURE} { fprintf(stderr, "[SCH:%s]", yytext); yylval.str = strdup(yytext); BEGIN(Schedule01); return FEATURE; }
<Schedule01>{MINUTE}  { fprintf(stderr, "[MI:%s]", yytext); yylval.num = atoi(yytext);                       return MINUTE; }
<Schedule01>"*"       { fprintf(stderr, "[MI:*]");                                                           return star; }
<Schedule01>","       { fprintf(stderr, ",");                                                                return comma; }
<Schedule01>"-"       { fprintf(stderr, "-");                                                                return minus; }
<Schedule01>"&"       { fprintf(stderr, "&");                                             BEGIN(Schedule02); return and; }
<Schedule02>{HOUR}    { fprintf(stderr, "[HR:%s]", yytext); yylval.num = atoi(yytext);                       return HOUR; }
<Schedule02>"*"       { fprintf(stderr, "[HR:*]");                                                           return star; }
<Schedule02>","       { fprintf(stderr, ",");                                                                return comma; }
<Schedule02>"-"       { fprintf(stderr, "-");                                                                return minus; }
<Schedule02>"&"       { fprintf(stderr, "&");                                             BEGIN(Schedule03); return and; }
<Schedule03>{DAYOFM}  { fprintf(stderr, "[DM:%s]", yytext); yylval.num = atoi(yytext);                       return DAYOFM; }
<Schedule03>"*"       { fprintf(stderr, "[DM:*]");                                                           return star; }
<Schedule03>","       { fprintf(stderr, ",");                                                                return comma; }
<Schedule03>"-"       { fprintf(stderr, "-");                                                                return minus; }
<Schedule03>"&"       { fprintf(stderr, "&");                                             BEGIN(Schedule04); return and; }
<Schedule04>{DAYOFM}  { fprintf(stderr, "[DR:%s]", yytext); yylval.num = atoi(yytext);                       return DAYOFM; }
<Schedule04>"*"       { fprintf(stderr, "[DR:*]");                                                           return star; }
<Schedule04>","       { fprintf(stderr, ",");                                                                return comma; }
<Schedule04>"-"       { fprintf(stderr, "-");                                                                return minus; }
<Schedule04>"&"       { fprintf(stderr, "&");                                             BEGIN(Schedule05); return and; }
<Schedule05>{MONTH}   { fprintf(stderr, "[MN:%s]", yytext); yylval.num = atoi(yytext);                       return MONTH; }
<Schedule05>"*"       { fprintf(stderr, "[MN:*]");                                                           return star; }
<Schedule05>","       { fprintf(stderr, ",");                                                                return comma; }
<Schedule05>"-"       { fprintf(stderr, "-");                                                                return minus; }
<Schedule05>"&"       { fprintf(stderr, "&");                                             BEGIN(Schedule06); return and; }
<Schedule06>{DAYOFW}  { fprintf(stderr, "[DW:%s]", yytext); yylval.num = atoi(yytext);                       return DAYOFW; }
<Schedule06>"*"       { fprintf(stderr, "[DW:*]");                                                           return star; }
<Schedule06>","       { fprintf(stderr, ",");                                                                return comma; }
<Schedule06>"-"       { fprintf(stderr, "-");                                                                return minus; }
<Schedule06>"|"       { fprintf(stderr, "|");                                             BEGIN(Schedule01); return or; }
 
<*>{

"task"       { fprintf(stderr, "task");      BEGIN(Task);    return task; }
"with"       { fprintf(stderr, "with");      BEGIN(Feature); return with; }
"="          { fprintf(stderr, "=");         BEGIN(Value);   return equal; }
","          { fprintf(stderr, ",");         BEGIN(Feature); return comma; }
":"          { fprintf(stderr, ":");                         return colon; }
"when"       { fprintf(stderr, "when");      BEGIN(Call);    return when; }
"submitted"  { fprintf(stderr, "submitted"); BEGIN(Number);  return submitted; }
"running"    { fprintf(stderr, "running");   BEGIN(Number);  return running; }
"failed"     { fprintf(stderr, "failed");    BEGIN(Number);  return failed; }
"suspended"  { fprintf(stderr, "suspended"); BEGIN(Number);  return suspended; }
"succeeded"  { fprintf(stderr, "succeeded");                 return succeeded; }
"skipped"    { fprintf(stderr, "skipped");                   return skipped; }
"submit"     { fprintf(stderr, "submit");    BEGIN(INITIAL); return submit; }
"same"       { fprintf(stderr, "same");                      return same; }
"next"       { fprintf(stderr, "next");                      return next; }
"future"     { fprintf(stderr, "future");                    return future; }
"succeed"    { fprintf(stderr, "succeed");   BEGIN(INITIAL); return succeed; }
"skip"       { fprintf(stderr, "skip");      BEGIN(INITIAL); return skip; }
"fail"       { fprintf(stderr, "fail");      BEGIN(INITIAL); return fail; }
"run"        { fprintf(stderr, "run");       BEGIN(INITIAL); return run; }
"caller"     { fprintf(stderr, "caller");                    return caller; }
"suspend"    { fprintf(stderr, "suspend");   BEGIN(INITIAL); return suspend; }
"after"      { fprintf(stderr, "after");     BEGIN(Number);  return after; }
"s"          { fprintf(stderr, "s");         BEGIN(Number);  return s; }
"m"          { fprintf(stderr, "m");         BEGIN(Number);  return m; }
"h"          { fprintf(stderr, "h");         BEGIN(Number);  return h; }
"times"      { fprintf(stderr, "times");                     return times; }
"then"       { fprintf(stderr, "then");                      return then; }
"call"       { fprintf(stderr, "call");      BEGIN(Call);    return call; }
"||"         { fprintf(stderr, "||");        BEGIN(Call);    return par; }
"->"         { fprintf(stderr, "->");        BEGIN(Call);    return seq; }
"execute"    { fprintf(stderr, "execute");   BEGIN(INITIAL); return execute; }
"generate"   { fprintf(stderr, "generate");  BEGIN(INITIAL); return generate; }
"always"     { fprintf(stderr, "always");                    return always; }
"once"       { fprintf(stderr, "once");                      return once; }
"twice"      { fprintf(stderr, "twice");                     return twice; }
"("          { fprintf(stderr, "(");                         return lparenthesis; }
")"          { fprintf(stderr, ")");                         return rparenthesis; }
"&"          { fprintf(stderr, "&");         BEGIN(Call);    return and; }
"|"          { fprintf(stderr, "|");         BEGIN(Call);    return or; }
";"          { fprintf(stderr, ";");         BEGIN(INITIAL); return semicolon; }

{COMMENT}    { fprintf(stderr, "[#:%s]\n", strndup(yytext + sizeof(char), strlen(yytext) - 2 * sizeof(char))); }
[ \t\n]+     { /* eat up whitespace */ fprintf(stderr, "%s", yytext); }
<<EOF>>      { return 0; }

}

<Task>{TASK}         { fprintf(stderr, "[TSK:%s]", yytext); yylval.str = strdup(yytext); BEGIN(Feature);    return TASK; }
<Call>{CALL}         { fprintf(stderr, "[CAL:%s]", yytext); yylval.str = strdup(yytext); BEGIN(Value);      return CALL; }
<Feature>{FEATURE}   { fprintf(stderr, "[FTR:%s]", yytext); yylval.str = strdup(yytext);                    return FEATURE; }
<Value>{VALUE}       { fprintf(stderr, "[VAL:%s]", yytext); yylval.str = strdup(yytext);                    return VALUE; }
<Number>{NUMBER}     { fprintf(stderr, "[NUM:%s]", yytext); yylval.num = atoi(yytext);   BEGIN(INITIAL);    return NUMBER; }

%%

/*
int main ()
{
    yylex();
    return 0;
}
*/
