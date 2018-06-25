" nvim main configuration file
"
" (C) 2018 Roosembert Palacios - released under CC-BY-SA
" ------------------------------------------------------------------------------
" PATHS: XDG <3 {{{

" Scripts' location:
set runtimepath=$XDG_DATA_HOME/nvim,$XDG_DATA_HOME/nvim/after,$VIM,$VIMRUNTIME

" Backup files:
set backupdir=$XDG_RUNTIME_DIR/nvim/backup

" Swap files:
set directory=$XDG_DATA_HOME/nvim/swap

" Command and undo history:
set viminfo+=n$XDG_DATA_HOME/nvim/viminfo
set undofile
set undodir=$XDG_DATA_HOME/nvim/undo
au BufWritePre /tmp/*,/dev/shm/*,/run/shm/* setl noundofile

" Make sure the damn paths exists:
function! MakeSureTheDamnPathExists(path)
  if !isdirectory(a:path)
    call mkdir(a:path, 'p', 0700)
  endif
endfunction

call MakeSureTheDamnPathExists($XDG_RUNTIME_DIR.'/vim')
call MakeSureTheDamnPathExists($XDG_DATA_HOME.'/vim')
call MakeSureTheDamnPathExists(&directory)
call MakeSureTheDamnPathExists(&undodir)
call MakeSureTheDamnPathExists(&backupdir)

" }}}
" ------------------------------------------------------------------------------
" BUNDLES {{{

let g:bundledir=$XDG_DATA_HOME.'/nvim/vim-plug'

if has('vim_starting')
  if !filereadable($XDG_DATA_HOME.'/nvim/site/autoload/plug.vim')
    !curl -fLo $XDG_DATA_HOME/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  endif
  set runtimepath+=$XDG_DATA_HOME/nvim/site
endif

call plug#begin(g:bundledir)

Plug 'vim-airline/vim-airline'
Plug 'scrooloose/nerdtree'
Plug 'brooth/far.vim'
Plug 'vim-scripts/Mark'

Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'Shougo/denite.nvim'

Plug 'Lokaltog/vim-easymotion'
Plug 'mileszs/ack.vim'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-tbone'
Plug 'tpope/vim-surround'
Plug 'yuratomo/w3m.vim'
Plug 'w0rp/ale'

Plug 'Shougo/vinarise.vim'        " Hex editor
Plug 'ap/vim-css-color'
Plug 'haya14busa/incsearch.vim'
Plug 'chrisbra/vim-diff-enhanced'

Plug 'jceb/vim-orgmode'
Plug 'tpope/vim-speeddating'
Plug 'LnL7/vim-nix'
Plug 'sophacles/vim-processing'
Plug 'idris-hackers/idris-vim'

call plug#end()

" Use ag instead of ack if possible
if executable('ag')
  let g:ackprg = 'ag --vimgrep'
endif

" }}}
" ------------------------------------------------------------------------------
" SYNTAX {{{

" Without any syntax highlighting, programming is a pain:
syntax on

" Fix unrecognised file types:
au BufRead,BufNewFile *.md setl filetype=markdown
au BufRead,BufNewFile *.tex setl filetype=tex
au BufRead,BufNewFile *.frag,*.vert,*.geom,*.glsl setl filetype=glsl
au BufRead,BufNewFile dunstrc,redshift.conf setl filetype=cfg
au BufRead,BufNewFile *.target setl filetype=systemd

" Assembly:
let asmsyntax='nasm'

" C:
let c_no_curly_error=1 " Allow {} inside [] and () (non-ANSI)
let c_space_errors=1   " Highlight trailing spaces and spaces before tabs
let c_syntax_for_h=1   " Treat .h as C header files (instead of C++)

" Shell:
let g:is_posix=1       " /bin/sh is POSIX shell, not deprecated Bourne shell

au FileType vhdl call FT_vhdl()
au FileType c call FT_c()
au FileType python call FT_python()
" }}}
" ------------------------------------------------------------------------------
" LANGUAGE-SPECIFIC {{{
function! s:GenTags(sources)
  let temp_tags_file=tempname()
  execute "!ctags -f " . temp_tags_file . " -R " . a:sources
  execute "set tags=" . temp_tags_file
  set notagrelative
endfunction

" -> VHDL {{{
function! FT_vhdl()
  setlocal tabstop=4
  setlocal shiftwidth=4
  if exists("+omnifunc")
    setlocal omnifunc=syntaxcomplete#Complete
  endif
  setlocal errorformat=**\ Error:\ %f(%l):\ %m,**\ Warning:\ %f(%l):\ %m
  let g:vhdl_indent_genportmap=0
  map <buffer> <F4> :execute ':!vsim -c -do "run -all;exit" '.expand("%:t:r")<CR>
  " for taglist
  let g:tlist_vhdl_settings = 'vhdl;d:package declarations;b:package bodies;e:entities;a:architecture specifications;t:type declarations;p:processes;f:functions;r:procedures'
  " abbreviations
  iabbr dt downto
  iabbr sig signal
  iabbr gen generate
  iabbr ot others
  iabbr sl std_logic
  iabbr slv std_logic_vector
  iabbr uns unsigned
  iabbr toi to_integer
  iabbr tos to_unsigned
  iabbr tou to_unsigned

  function! s:GenTags(sources)
    let temp_tags_file=tempname()
    execute "!ctags --options=$HOME/.local/lib/ctags/vhdl -f " . temp_tags_file . " -R " . a:sources
    execute "set tags=" . temp_tags_file
    set notagrelative
  endfunction
endfunction
" }}} <- VHDL

" -> C {{{
function! FT_c()
  function! s:SetSingletonMake()
    let &l:makeprg="gcc " . expand("%") ." -o " . expand("%:r") . " -W -Wall -Wextra -pedantic -Wcast-align -Wcast-qual -Wconversion -Wwrite-strings -Wfloat-equal -Wpointer-arith -Wformat=2 -Winit-self -Wuninitialized -Wshadow -Wstrict-prototypes -Wmissing-declarations -Wmissing-prototypes -Wno-unused-parameter -Wbad-function-cast -Wunreachable-code -O0 -g"
  endfunction
  command! SetSingletonMake call s:SetSingletonMake()
endfunction
" }}} <- C

" -> Python {{{
function! FT_python()
  function! s:GenTags(sources)
    let temp_tags_file=tempname()
    execute "!ctags -f " . temp_tags_file . " -R " . a:sources
    execute "set tags=" . temp_tags_file
    set notagrelative
  endfunction
endfunction
" }}} <- Python

function! s:_GenTags(...)
  if a:0 == 1
    call s:GenTags(a:1)
  else
    call s:GenTags(".")
  endif
endfunction

command! -nargs=? -complete=dir GenTags call s:_GenTags("<args>")
" }}}
" ------------------------------------------------------------------------------
" WHITESPACE {{{

" Fix trailing whitespaces when saving file with `:W`:
function! StripTrailingWhitespaces()
  let _s=@/
  let l=line('.')
  let c=col('.')
  %s/\s\+$//eg
  call cursor(l,c)
  let @/=_s
endfunction
command! W :call StripTrailingWhitespaces() | :write

" Fold C function implemenations:
function! CFold()
  let prevline = getline(v:lnum-1)
  let nextline = getline(v:lnum+1)
  if match(nextline, '^{') >= 0
    return 1
  elseif match(prevline, '^}') >= 0
    return 0
  else
    return "="
  endif
endfunction
au FileType c setl foldmethod=expr
au FileType c setl foldexpr=CFold()

" Auto-indent, and reuse the same combination of spaces/tabs:
filetype plugin indent on
set autoindent
set copyindent

" Indentation (tabs, spaces):
set expandtab tabstop=2 shiftwidth=2
au FileType c setl tabstop=4 shiftwidth=4

" Visually wrap lines and break words:
set wrap
au FileType html,java,markdown,scala setl nowrap
set linebreak      " wrap at words (does not work with list)

" Physically wrap lines:
au FileType markdown setl textwidth=120
au FileType gitcommit setl textwidth=86
" }}}
" ------------------------------------------------------------------------------
" LOOK {{{

" Colors, after syntax!, `syntax enable` doesn't seems to work...
" FIXME: Copy it to nvim!
source $XDG_CONFIG_HOME/vim/colors.vim

" statusline!
"source $XDG_CONFIG_HOME/vim/statusline.vim

" Display and format line numbers:
set number
set relativenumber
set numberwidth=5

" Display a bar after a reasonable number of columns:
set colorcolumn=81,121
au FileType mail,gitcommit setl colorcolumn=87

" I wanna see tabs and trailing whitespaces:
set list
set listchars=tab:→\ ,eol:\ ,trail:·

" Window separator:
if $TERM == 'linux'
  set fillchars=vert:.
else
  set fillchars=vert:│
endif

" Fold fill characters:
set fillchars+="fold: "

" Autofold (except in git commit message):
set foldmethod=marker
au FileType gitcommit setl foldmethod=manual

" }}}
" ------------------------------------------------------------------------------
" KEY BINDINGS, BEHAVIOUR {{{

" Leader key:
let mapleader=' '

" Keep 3 lines 'padding' above/below the cursor:
set scrolloff=3

" Simple cursor moving on visual lines:
map k gk
map j gj

" Remove delay for leaving insert mode:
set timeoutlen=1000 ttimeoutlen=0

" Window manipulation: Resize window
nnoremap <leader>K <C-W>+
nnoremap <leader>J <C-W>-
nnoremap <leader>L <C-W>>
nnoremap <leader>H <C-W><

" Manipulate windows: Move between windows
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Open underlying file in splits:
nmap <C-w>w :rightbelow wincmd f<CR>
nmap <C-w>e :rightbelow vertical wincmd f<CR>

" Tabbed window handling:
map <leader>l :tabnext<CR>
map <leader>h :tabprevious<CR>
map <leader>t :tabnew<CR>
set tabpagemax=20

" Show 10 last commands in the window
set cmdwinheight=10

" Save a file as root (WARNING: breaks file undo history):
" command! Rw :execute ':silent w !sudo tee % > /dev/null' | :edit!
cmap w!! w !sudo tee % >/dev/null<CR>

" NERDTree
nmap <leader>o :NERDTreeToggle<CR>

" Denite
nmap <leader>f :DeniteProjectDir file_rec -auto-preview<CR>
nmap <leader>b :DeniteBufferDir buffer -auto-preview<CR>

" Fugitive
nmap <leader>s :Gstatus<CR>

" Quickfix
nmap <leader>L :cclose<CR>
nmap <leader>l :copen<CR>
nmap <leader>k :cprevious<CR>
nmap <leader>j :cnext<CR>

" Incsearch
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

" Execure the line under the cursor
vmap ! :!sh<CR>

" Ignore case when searching, except when explicitely using Uppercase:
set ignorecase smartcase

" Highlight matching open parentheses when closing:
set showmatch

" enable mouse everywhere but in command-line mode
set mouse=nvi

" }}}
" ------------------------------------------------------------------------------
