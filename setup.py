import os,setuptools
with open("README.md","r",encoding="utf-8") as r:
  long_description=r.read()
URL="https://github.com/KoichiYasuoka/GuwenCOMBO"

setuptools.setup(
  name="guwencombo",
  version="1.6.1",
  description="Tokenizer POS-tagger and Dependency-parser for Classical Chinese",
  long_description=long_description,
  long_description_content_type="text/markdown",
  url=URL,
  author="Koichi Yasuoka",
  author_email="yasuoka@kanji.zinbun.kyoto-u.ac.jp",
  license="GPL",
  keywords="NLP Chinese",
  packages=setuptools.find_packages(),
  install_requires=["udkundoku>=2.2.9","unidic_combo>=1.5.2"],
  python_requires=">=3.6",
  package_data={"guwencombo":["download/*.txt"]},
  classifiers=[
    "License :: OSI Approved :: GNU General Public License (GPL)",
    "Programming Language :: Python :: 3",
    "Operating System :: OS Independent",
    "Topic :: Text Processing :: Linguistic"
  ],
  project_urls={
    "COMBO-pytorch":"https://gitlab.clarin-pl.eu/syntactic-tools/combo",
    "Source":URL,
    "Tracker":URL+"/issues",
  }
)
