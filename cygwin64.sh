#! /bin/sh -x
# UniDic-COMBO installer for Cygwin64, which requires:
#   python37-devel python37-pip python37-cython python37-numpy python37-cffi
#   gcc-g++ mingw64-x86_64-gcc-g++ gcc-fortran git curl make cmake
#   libopenblas liblapack-devel libhdf5-devel libfreetype-devel libuv-devel
case "`uname -a`" in
*'x86_64 Cygwin') : ;;
*) echo Only for Cygwin64 >&2
   exit 2 ;;
esac
F=''
for P in python37-devel python37-pip python37-cython python37-numpy python37-cffi gcc-g++ mingw64-x86_64-gcc-g++ gcc-fortran git curl make cmake libopenblas liblapack-devel libhdf5-devel libfreetype-devel libuv-devel
do if [ ! -s /etc/setup/$P.lst.gz ]
   then F="$F $P"
   fi
done
case "$F" in
'') : ;;
*) echo $F not installed >&2
   exit 2 ;;
esac
ALLENNLP_VERSION=1.4.1
TOKENIZERS_VERSION=0.9.4
export ALLENNLP_VERSION TOKENIZERS_VERSION
pip3.7 install 'torch>=1.6.0' -f https://github.com/KoichiYasuoka/CygTorch
curl -L https://raw.githubusercontent.com/KoichiYasuoka/CygTorch/master/installer/allennlp.sh | sh -x
pip3.7 install tokenizers==$TOKENIZERS_VERSION guwencombo
exit 0
