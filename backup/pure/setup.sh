#!/bin/bah

set -e

PROJECT_DIR=$(git rev-parse --show-toplevel)
PURE_URL="https://github.com/cofess/hexo-theme-pure"
PURE_DIR=$PROJECT_DIR/themes/pure
PURE_CONFIG=$PROJECT_DIR/backup/pure/_config.yml
PURE_AVATAR=$PROJECT_DIR/backup/pure/avatar.jpg

if [ -d $PURE_DIR ] || [ -f $PURE_DIR ]; then
    echo "file or directory $PURE_DIR already exists"
    exit 1
fi

git clone $PURE_URL $PURE_DIR
cp $PURE_CONFIG $PURE_DIR
cp $PURE_AVATAR $PURE_DIR/source/images/
