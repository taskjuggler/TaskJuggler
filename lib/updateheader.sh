files="*.rb taskjuggler/*.rb taskjuggler/apps/*.rb
taskjuggler/daemon/*.rb taskjuggler/reports/*.rb
taskjuggler/RichText/*.rb taskjuggler/TextParser/*.rb ../test/*.rb
../spec/*.rb ../spec/support/*.rb" 

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
