#! /bin/sh
if [ $# -eq 0 ]
then set guwen-combo-small guwen-combo
fi
for M
do if [ -s $M.tar.gz ]
   then continue
   elif [ -s $M.tar.gz.1 ]
   then cat $M.tar.gz.[1-9] > $M.tar.gz
   elif [ -s lzh_kyoto.conllu ]
   then cat lzh_kyoto.conllu | python3 -c '
c=[]
while True:
  try:
    s=input()
  except:
    quit()
  t=s.split("\t")
  if len(t)==10:
    if t[0]!="#":
      c.append(s)
  elif s.strip()=="":
    if len(c)>1:
      print("\n".join(c)+"\n")
    c=[]
' | tee traditional.conllu | python3 -c '
from guwencombo.simplify import simplify
c=[]
while True:
  try:
    s=input()
  except:
    quit()
  t=s.split("\t")
  if len(t)==10:
    if t[0]!="#":
      u=""
      for i in t[1]:
        if i in simplify:
          u+=simplify[i]
        else:
          u+=i
      t[1]=u
      c.append("\t".join(t))
  elif s.strip()=="":
    if len(c)>1:
      print("\n".join(c)+"\n")
    c=[]
' > simplified.conllu
        case $M in
        *-small) python3 -m unidic_combo.main --mode train --cuda_device 0 --num_epochs 100 --training_data_path traditional.conllu --targets deprel,head,upostag,feats --features token,char,xpostag,lemma ;;
        *) python3 -m unidic_combo.main --mode train --cuda_device 0 --num_epochs 100 --pretrained_transformer_name ethanyt/guwenbert-base --training_data_path simplified.conllu --targets deprel,head,upostag,feats --features token,char,xpostag,lemma ;;
        esac
        cp `ls -1t /tmp/allennlp*/model.tar.gz | head -1` $M.tar.gz
        split -a 1 -b 83886080 --numeric-suffixes=1 $M.tar.gz $M.tar.gz.
   fi
done
exit 0
