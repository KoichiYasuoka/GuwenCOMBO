#! /usr/bin/python3 -i
# coding=utf-8

import os,udkanbun
PACKAGE_DIR=os.path.abspath(os.path.dirname(__file__))
DOWNLOAD_DIR=os.path.join(PACKAGE_DIR,"download")
MODEL_URL="https://raw.githubusercontent.com/KoichiYasuoka/GuwenCOMBO/main/guwencombo/download/"
filesize={}
with open(os.path.join(DOWNLOAD_DIR,"filesize.txt"),"r") as f:
  r=f.read()
for t in r.split("\n"):
  s=t.split()
  if len(s)==2:
    filesize[s[0]]=int(s[1])

class GuwenCOMBO(udkanbun.UDKanbun):
  def __init__(self,danku,model):
    import unidic_combo.predict
    self.danku=danku
    try:
      from MeCab import Tagger
    except:
      from fugashi import GenericTagger as Tagger
    self.mecab=Tagger("-r "+os.path.join(udkanbun.PACKAGE_DIR,"mecabrc")+" -d "+os.path.join(udkanbun.PACKAGE_DIR,"mecab-kanbun"))
    if model==None:
      model="guwen-combo.tar.gz"
    self.simplified=(model=="guwen-combo.tar.gz")
    f=os.path.join(DOWNLOAD_DIR,model)
    try:
      s=os.path.getsize(f)
      if filesize[model]!=s:
        s=-1
    except:
      s=-1
    if s<0:
      from unidic_combo import download
      download(MODEL_URL,model,DOWNLOAD_DIR)
    self.model=unidic_combo.predict.COMBO.from_pretrained(f)
    self.udpipe=GuwenAPI(self.model,self.simplified)

class GuwenAPI(object):
  def __init__(self,model,simplified):
    self.model=model
    self.simplified=simplified
  def process(self,conllu):
    from unidic_combo.data import Token,Sentence,sentence2conllu
    u=[]
    e=[]
    for s in conllu.split("\n"):
      if s=="" or s.startswith("#"):
        if e!=[]:
          u.extend(self.model([Sentence(tokens=e)]))
          e=[]
      else:
        t=s.split("\t")
        if self.simplified:
          i=t[9].find("Translit=")
          if i<0:
            if t[4]=="n,名詞,*,*":
              from guwencombo.simplify import simplify
              if t[1] in simplify:
                j=simplify[t[1]]
                t[9]=("" if t[9]=="_" else t[9]+"|")+"Translit="+j+"|Original="+t[1]
                t[1]=j
          else:
            j=t[9][i+9:]
            t[9]+="|Original="+t[1]
            t[1]=j
        e.append(Token(id=int(t[0]),token=t[1],lemma=t[2],upostag=t[3],xpostag=t[4],misc=t[9]))
    for s in u:
      for t in s.tokens:
        if t.deprel=="root":
          if t.head!=0:
            t.deprel="advcl" if t.head>t.id else "parataxis"
        if t.head==0 or t.head==t.id:
          t.head=0
          t.deprel="root"
        i=t.misc.find("|Original=")
        if i>=0:
          t.token=t.misc[i+10:]
          t.misc=t.misc[0:i]
    return "".join([sentence2conllu(s,False).serialize() for s in u])

def load(BERT=True,Danku=False):
  model="guwen-combo.tar.gz" if BERT else "guwen-combo-small.tar.gz"
  nlp=GuwenCOMBO(Danku,model)
  return nlp
