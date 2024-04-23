autoload -U colors && colors
export LS_COLORS="di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

setopt prompt_subst

CURRENT_BG='NONE'
CURRENT_FG='black'
SEGMENT_SEPARATOR=$'\ue0b0'

function __git_dirty() {
    [[ -n "$(git status -s 2> /dev/null)" ]] && echo "*"
}

function __construct_segment() {
    local bg fg
    [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
    [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
    if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
        echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
    else
        echo -n "%{$bg%}%{$fg%} "
    fi
    CURRENT_BG=$1
    [[ -n $3 ]] && echo -n $3
}

function prompt_status() {
    local -a symbols

    [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
    [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
    [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

    [[ -n "$symbols" ]] && __construct_segment black default "$symbols"
}

function prompt_virtualenv() {
    if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]; then
        __construct_segment black default "(${VIRTUAL_ENV:t:gs/%/%%})"
    fi
}

function prompt_condaenv() {
    if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
        __construct_segment black default "($CONDA_DEFAULT_ENV)"
    fi
}

function prompt_context() {
    if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
        __construct_segment black default "%(!.%{%F{yellow}%}.)%n"
    fi
}

function prompt_dir() {
    __construct_segment blue $CURRENT_FG '%~'
}

function prompt_git() {
    (( $+commands[git] )) || return

    local PL_BRANCH_CHAR
    () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0'
}

local ref dirty mode repo_path

if [[ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = "true" ]]; then
    repo_path=$(git rev-parse --git-dir 2> /dev/null)
    dirty=$(__git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || \
        ref="◈ $(git describe --exact-match --tags HEAD 2> /dev/null)" || \
        ref="➦ $(git rev-parse --short HEAD 2> /dev/null)" 

    if [[ -n $dirty ]]; then
        __construct_segment yellow black
    else
        __construct_segment green $CURRENT_FG
    fi

    local ahead behind
    ahead=$(git log --oneline @{upstream}.. 2> /dev/null)
    behind=$(git log --oneline ..@{upstream} 2> /dev/null)
    if [[ -n "$ahead" ]] && [[ -n "$behind" ]]; then
        PL_BRANCH_CHAR=$'\u21c5'
    elif [[ -n "$ahead" ]]; then
        PL_BRANCH_CHAR=$'\u21b1'
    elif [[ -n "$behind" ]]; then
        PL_BRANCH_CHAR=$'\u21b0'
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
        mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
        mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
        mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:*' unstagedstr '±'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'

    vcs_info
    echo -n "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
fi
}

function prompt_end() {
    if [[ -n $CURRENT_BG ]]; then
        echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
    else
        echo -n "%{%k%}"
    fi
    echo -n "\e[m\n %{%f%}"
    CURRENT_BG=''
}

function build_prompt() {
    RETVAL=$?
    prompt_status
    prompt_virtualenv
    prompt_condaenv
    prompt_context
    prompt_dir
    prompt_git
    prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '
