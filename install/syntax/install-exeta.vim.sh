mkdir -p ~/.vim/syntax
cp exeta.vim ~/.vim/syntax
mkdir -p ~/.vim/ftdetect
echo "au BufRead,BufNewFile *.e set filetype=exeta" > ~/.vim/ftdetect/exeta.vim
