files=*.rb

for f in $files; do
  sed "s/\$FILE/$f/g" header.tmpl > header
  firstLine=`head -1 $f`
  if test "$firstLine" == "#"; then
    sed '1,9d' $f > tmpfile
    mv -f tmpfile $f
  fi
  cat header $f > tmpfile
  mv -f tmpfile $f
done
