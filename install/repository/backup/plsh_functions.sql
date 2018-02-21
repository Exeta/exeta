create or replace function exeta.bash (text) returns text
language plsh
as
\$function$
#!/bin/bash
bash <<EOF
\$1
EOF
\$function$
;

grant execute on function exeta.bash (text) to martin;

--select exeta.bash('x=1'||chr(10)||'y=\$((x+1))'||chr(10)||'z=A'||chr(10)||'echo test \${x}\${z}\${y}'||chr(10)||'echo Ahoj');
