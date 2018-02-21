EXETA_HOME=~/Exeta

# install exeta mime type
mkdir -p ~/.local/share/mime/packages
cp exeta.xml ~/.local/share/mime/packages
cd ~/.local/share
update-mime-database mime

# install exeta language specification
mkdir -p ~/.local/share/gtksourceview-3.0/language-specs
cp exeta.lang ~/.local/share/gtksourceview-3.0/language-specs

