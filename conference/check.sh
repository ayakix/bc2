#!/bin/bash
# Find bc2 path
COL_GREEN="\033[1;32m"
COL_RED="\033[1;31m"
COL_CYAN="\033[1;36m"
COL_BLUE="\033[1;34m"
COL_YELLOW="\033[1;33m"
COL_CLR="\033[m"

function print()
{
    echo -e "\n"$COL_CYAN"$@"$COL_CLR
}

function nberr()
{
    echo -e $COL_RED"✗ $@"$COL_CLR
}

function err()
{
    echo -e $COL_RED"✗ $@"$COL_CLR
    exit 1
}

function ok()
{
    echo -e $COL_GREEN"✓ $@"$COL_CLR
}

function warn()
{
    echo -e $COL_YELLOW"$@"$COL_CLR
}

function fexistchk()
{
    fname="$1"
    if [ -e "$fname" ]; then
        ok "${fname}が存在します"
        return 0
    fi
    shift
    err "${fname}が存在しません。$*"
}

function execchk()
{
    echo "$ $@"
    "$@"
    if [ $? -ne 0 ]; then
        err "エラー発生：$@0"
    fi
}

function appchk()
{
    BC2PATH=$BC2CHECKPATH/../$1
    PRODUCT=$1
    TARGET=$2
    VERSIONROOT=$3
    cd $BC2PATH && BC2PATH=$(pwd)
    print "BC2フォルダー: $COL_BLUE$BC2PATH"
    
    if [ ! -e "$BC2PATH/src/bitcoin-cli.cpp" ]; then
        warn "BC2フォルダーが正しくないようです。"
        warn "$BC2PATH/src/bitcoin-cli.cppというファイルが存在しません。"
        err "BC2フォルダーが見つかりませんでした"
    fi
    
    # git 確認
    print "repoのチェック:"
    
    branch=$(git symbolic-ref --short HEAD)
    CHANGES=$(git diff-index --name-only HEAD --)
    
    # Checking repository
    if [ "$branch" != "${TARGET}" ]; then
        warn "branchが${TARGET}ではありません。（${branch}です）"
        warn "${TARGET}のbranchに戻してからチェックを行って下さい"
        warn "戻す方法："
        warn "  git checkout ${TARGET}"
        if [ -n "$CHANGES" ]; then
            warn "エラーが出たら、自分が変えたファイルをコミットしていない可能性があります"
            warn "ファイルを保存したい場合は、"
            warn "  git commit -am \"メッセージ\""
            warn "を入れてから"
            warn "  git checkout ${TARGET}"
            warn "を入れると良いです。"
            warn "リセットしたい場合は、"
            warn "  git reset --hard origin/${TARGET}"
            warn "を入れるとなくなります。gitのマニュアルを参考に。"
        fi
        err "branchが${TARGET}ではありません"
    fi
    ok "branch=${TARGET}"
    
    # Checking git changes
    if [ -n "$CHANGES" ]; then
        warn "gitにコミットされていないファイルが以下のようにあります："
        echo $CHANGES
        warn "ファイルを保存したければ、新しいbranchを作って、コミットして下さい。例："
        warn "  git checkout -b $USER-test"
        warn "リセットしたい場合は、"
        warn "  git reset --hard origin/${TARGET}"
        err "repoがcleanではありません"
    fi
    ok "repoはclean"
    
    # Checking if up to date
    git fetch origin ${TARGET} 2>/dev/null
    CURRCOMMIT=$(git rev-parse HEAD)
    LATESTCOMMIT=$(git rev-parse origin/${TARGET})
    if [ "$CURRCOMMIT" != "$LATESTCOMMIT" ]; then
        warn "最新のrepoではありません。"
        warn "最新のrepoにする為に、"
        warn "  git pull"
        warn "を入れる必要があります。"
        err "最新のrepoではありません"
    fi
    ok "最新のrepo確認"
    
    # BC2 binary check
    print "${PRODUCT}のチェック："
    
    cd "$BC2PATH/src"
    HINT="コンパイルする必要があるかもしれません： makeを入れたらコンパイルします。"
    fexistchk ./${PRODUCT}d "$HINT"
    fexistchk ./${PRODUCT}-cli "$HINT"
    
    SHORTCOMMIT=${LATESTCOMMIT:0:7}
    GOTVERSION=$(./${PRODUCT}-cli -version)
    EXPVERSION="${VERSIONROOT}-$SHORTCOMMIT"
    
    if [ "${GOTVERSION:0:${#EXPVERSION}}" != "$EXPVERSION" ]; then
        warn "バージョンが違います。"
        warn "  現在：$GOTVERSION"
        warn "  想定：$EXPVERSION"
        warn "恐らくコンパイルする必要があります。"
        warn "  make"
        warn "を入れるとコンパイルが行われます。エラーが出た場合、"
        warn "  cd \"$BC2PATH\""
        warn "  ./autogen.sh"
        warn "  ./configure"
        warn "  make"
        warn "を入れる必要があるかもしれません。"
        err "想定外のバージョン"
    fi
    ok "バージョン確認"
}

print "環境チェック："
HOST_OS=linux
which systemctl &>/dev/null
if [ $? -ne 0 ]; then
    which launchctl &>/dev/null
    if [ $? -eq 0 ]; then
        # macOS
        HOST_OS=macos
    else
        # ???
        err "環境が確認出来ません"
    fi
fi
ok "OS=$HOST_OS"

DIRNAME=$(dirname $0)
if [ "$DIRNAME" = "." ]; then
    DIRNAME=""
fi
FULLPATH=$PWD/$DIRNAME
BC2CHECKPATH=${FULLPATH:0:$((${#FULLPATH}-11))}

appchk "bitcoin" "bc2" "BC2-Bitcoin Core RPC client version v0.14.99.0"
appchk "elements" "elements-bc2" "BC2-Elements Core RPC client version v0.14.1.0"

print "gmp"
case "${HOST_OS}" in
  "linux" )
    GMP=libgmp-dev
    GMPVERPTN='s/^[^:]*:\([0-9.]*\).*$/\1/'
    GMPINFO=$(apt list ${GMP} 2> /dev/null | grep "^${GMP}")
    EXISTSGMP=$(echo ${GMPINFO} | grep "インストール済み" &> /dev/null ; echo $?)
    ;;
  "macos" )
    GMP=gmp
    GMPVERPTN='s/^[^0-9.]*\([0-9.]*\).*$/\1/'
    GMPINFO=$(brew info ${GMP})
    EXISTSGMP=$(echo ${GMPINFO} | grep "Not installed" &> /dev/null ; test $? -ne 0 ; echo $?)
    ;;
esac
if [ $EXISTSGMP != 0 ]; then
    err "${GMP}が見つかりませんでした。インストールされていますか？"
fi
ok "${GMP}が存在します"

GOTGMPVER=$(echo ${GMPINFO} | grep "^${GMP}" | sed -e "${GMPVERPTN}")
EXPGMPVER="6.1.2"

if [ "${GOTGMPVER:0:${#EXPGMPVER}}" != "$EXPGMPVER" ]; then
    warn "gmpのバージョンが想定外です。"
    warn "  現在：$GOTGMPVER"
    warn "  想定：$EXPGMPVER"
    err "想定外のgmpバージョン"
fi
ok "バージョン確認"

echo ""
ok "*** Ａｌｌ　Ｃｌｅａｒ ***"
ok "Welcome to ＢＣ２ Season2！"
echo ""
