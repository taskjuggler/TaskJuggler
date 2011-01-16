files="*.rb reports/*.rb daemon/*.rb TextParser/*.rb ../test/*.rb ../spec/*.rb"

for f in $files; do
  basename=`basename $f`
  sed "s/\$FILE/$basename/g" header.tmpl > header
  firstLine=`head -1 $f`
  if test "$firstLine" == "#!/usr/bin/env ruby -w"; then
    sed '1,/^$/d' $f > tmpfile
    mv -f tmpfile $f
  else
    echo "$f has no header"
  fi
  cat header $f > tmpfile
  mv -f tmpfile $f
done
