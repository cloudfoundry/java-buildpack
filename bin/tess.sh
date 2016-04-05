#!/bin/bash
BUILD_DIR=$1
TESSERACT_OCR_VERSION=3.02.02
TESSERACT_OCR_DATA_VERSION=3.02

INSTALL_DIR=$BUILD_DIR/vendor/
INSTALL_DIR_TRAINING_DATA=$BUILD_DIR/vendor/
ENVSCRIPT=$BUILD_DIR/.profile.d/tesseract-ocr.sh
TESSERACT_OCR_REMOTE=https://s3-us-west-2.amazonaws.com/five9code/tesseract.tar.gz

echo 'Getting Tesseract-ocr Binaries'
echo "Location: $TESSERACT_OCR_REMOTE"
mkdir -p $INSTALL_DIR
curl $TESSERACT_OCR_REMOTE -o - | tar -xz -C $INSTALL_DIR -f -

echo 'Getting tesseract-ocr training data'
echo 'English training data'
curl https://tesseract-ocr.googlecode.com/files/tesseract-ocr-$TESSERACT_OCR_DATA_VERSION.eng.tar.gz \
  -o - | tar -xz -C $INSTALL_DIR_TRAINING_DATA -f -
if [ $TESSERACT_OCR_LANGUAGES ]
then
   array=(${TESSERACT_OCR_LANGUAGES//,/ })
   for i in "${!array[@]}"
   do
     lang="${array[i]}"
     echo $lang 'training data'
     echo https://tesseract-ocr.googlecode.com/files/tesseract-ocr-$TESSERACT_OCR_DATA_VERSION.$lang.tar.gz
     curl https://tesseract-ocr.googlecode.com/files/tesseract-ocr-$TESSERACT_OCR_DATA_VERSION.$lang.tar.gz \
  -o - | tar -xz -C $INSTALL_DIR_TRAINING_DATA -f -

   done
fi
echo "Building runtime environment for tesseract-ocr"
chmod +x $BUILD_DIR/vendor/tesseract-ocr/bin/*
mkdir -p $BUILD_DIR/.profile.d
echo "export PATH=\"\$PATH:\$HOME/vendor/tesseract-ocr/bin\"" > $ENVSCRIPT
echo "export LD_LIBRARY_PATH=\"\$LD_LIBRARY_PATH:\$HOME/vendor/tesseract-ocr/lib\"" >> $ENVSCRIPT
echo "export TESSDATA_PREFIX=\"\$HOME/vendor/tesseract-ocr/\"" >> $ENVSCRIPT
