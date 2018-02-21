" Vim syntax file
" Language: Exeta
" Maintainer: Martin Procházka
" Latest Revision: 2017-05-13

if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "exeta"

syntax case ignore
setlocal isident+=.
setlocal isident+=-

"syntax match sKeyword /\<when\>/

syntax region eTask matchgroup=eKeyword start=/\<task\>/ end=/\<with\>\|\<submit\>\|\<fail\>\|\<succeed\>\|\<skip\>\|\<suspend\>\|\<call\>\|\<generate\>\|\<execute\>/me=s-1 contains=eName,eIdentifier,eColon,eMember,eComment
syntax match eMember /\<\I\i*\>/ contained nextgroup=eMember skipwhite skipnl skipempty
syntax match eColon /:/ contained nextgroup=eMember skipwhite skipnl skipempty
syntax match eIdentifier /\<\I\i*\>/ contained nextgroup=eIdentifier,eColon skipwhite skipnl skipempty
syntax match eName /\<\I\i*\>/ contained nextgroup=eIdentifier skipwhite skipnl skipempty

syntax region eWith matchgroup=eKeyword start=/\<with\>/ end=/\<submit\>\|\<fail\>\|\<succeed\>\|\<skip\>\|\<suspend\>\|\<call\>\|\<generate\>\|\<execute\>\|\<run\>\|||\|->\|)\|;/me=s-1 contains=eFeature,eValue,eEnclosedValue,eFeatureValue,eComma,eList,eComment
syntax match eFeature /\<\I\i*\>/ contained nextgroup=eValue skipwhite skipnl skipempty
syntax region eValue start=/=/ms=e+1 end=/,\|\<submit\>\|\<fail\>\|\<succeed\>\|\<skip\>\|\<suspend\>\|\<call\>\|\<generate\>\|\<execute\>\|\<run\>\|||\|->\|)\|;/me=s-1 skip=/\\,/ contained contains=eFeatureValue,eList,eEnclosedValue,eComment
syntax region eList matchgroup=eNormal start=/\([^\\]\|^\)\@<=(/ matchgroup=eNormal end=/)/ skip=/\\)/ contained contains=eList,eEnclosedValue,eFeatureValue,eComment
syntax region eEnclosedValue matchgroup=eNormal start=/"/ matchgroup=eNormal end=/"/ skip=/\\"/ contained contains=eFeatureValue

"syntax region eCond matchgroup=eKeyword start=/\<when\>/ end=/\<submitted\>\|\<running\>\|\<succeeded\>\|\<skipped\>\|\<failed\>\|\<suspended\>/me=s-1 contains=eCondName,eFeatureValue,eComment
syntax region eCond start=/\<when\>/ms=e+1 end=/\<submitted\>\|\<running\>\|\<succeeded\>\|\<skipped\>\|\<failed\>\|\<suspended\>/me=s-1 contains=eCondName,eFeatureValue,eComment skipwhite skipnl skipempty
syntax region eCond1 start=/(\|&\|\([^|]\|^\)\@<=|\([^|]\|$\)\@=/ms=e+1 end=/\<submitted\>\|\<running\>\|\<succeeded\>\|\<skipped\>\|\<failed\>\|\<suspended\>/me=s-1 contains=eCondName,eFeatureValue,eComment skipwhite skipnl skipempty
syntax region eCondName start=/\(\I\|\${\I\i*}\)\(\i\|\${\I\i*}\)*/ms=e+1 end=/\<submitted\>\|\<running\>\|\<succeeded\>\|\<skipped\>\|\<failed\>\|\<suspended\>/me=s-1 contained contains=eFeatureValue,eList,eEnclosedValue skipwhite skipnl skipempty

syntax region eCall matchgroup=eKeyword start=/\<call\>/ end=/(\|\<with\>\|\<submit\>\|\<fail\>\|\<succeed\>\|\<skip\>\|\<suspend\>\|\<run\>\|||\|->\|)\|;/me=s-1 contains=eCallName,eFeatureValue,eComment
syntax region eCall1 start=/(\|||\|->/ms=e+1 end=/(\|\<with\>\|\<submit\>\|\<fail\>\|\<succeed\>\|\<skip\>\|\<suspend\>\|\<run\>\|||\|->\|)\|;/me=s-1 contains=eCallName,eFeatureValue,eComment
syntax region eCallName start=/\(\I\|\${\I\i*}\)\(\i\|\${\I\i*}\)*/ms=e+1 end=/\<with\>\|\<submit\>\|\<fail\>\|\<succeed\>\|\<skip\>\|\<suspend\>\|\<run\>\|||\|->\|)\|;/me=s-1 contained contains=eFeatureValue,eList,eEnclosedValue,eComment skipwhite skipnl skipempty

"syntax region eFeatureValue matchgroup=eNormal start=/\([^\\]\|^\)\@<=\${/ matchgroup=eNormal end=/}/ contains=eFeature,eComment
syntax region eFeatureValue start=/\([^\\]\|^\)\@<=\${/ms=e+1 end=/}/me=s-1 contains=eFeature,eComment

syntax keyword eKeyword when then generate execute once run submit same next future skip after s m h times twice submitted running succeeded skipped failed suspended

syntax region eComment start=/\([^\\]\|^\)\@<=#/ end=/$/

highlight link eComment Comment
highlight link eKeyword Type
highlight link eName  Statement
highlight link eIdentifier Identifier
highlight link eMember Identifier
highlight link eFeature Identifier
highlight link eValue Constant
highlight link eEnclosedValue Constant
highlight link eList Constant
highlight link eFeatureValueDelimiter Constant
highlight link eCall Statement
highlight link eCall1 Statement
highlight link eCallName Constant
highlight link eCond Statement
highlight link eCond1 Statement
highlight link eCondName Constant
highlight link eCallIdentifier Constant
highlight link eNormal Normal
