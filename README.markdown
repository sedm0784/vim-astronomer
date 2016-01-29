Astronomer
==========

*Studies space, so you don't have to.*

## What is Astronomer?

Astronomer is a plugin that scans files when they are opened, and
automatically sets Vim's indent and whitespace-handling options (`'expandtab'`,
`'shiftwidth'`, and `'tabstop'`) to appropriate values.

##  Didn't Tim Pope already write that?

Yes, yes he did, [and he did an excellent job, too][sleuth]. However, he
obviously doesn't have to wrestle with the same breed of QUALITY codebases
as I do, because his plugin is missing what I consider to be Astronomer's
most important feature of all.

[sleuth]: http://github.com/tpope/vim-sleuth

##  Which is?

It turns on `'list'` when it discovers inconsistent indentation.

## Couldn't I just turn list on in my .vimrc?

Well yes, you *could*, but I find having tabs visible *all* the time to be
DISTRACTING, unless I set their highlight colours to blend in with the
background like a TIGER in the jungle. But if I do *that*, then I tend not to
notice them at all.

Astronomer allows me to have list turned off unless I *really* need it: it's a
bit like having your own personal laundrette. But instead of taking care of your
whites, this laundrette takes care of your whitespace.

##  I hope you are better at writing Vimscript than you are at writing analogies.

There's only one way to find out!

## Okay, I'll give it a go. How do I get it?

I'd recommend installing [Pathogen][pathogen], and then running the commands:

    cd ~/.vim/bundle
    git clone https://github.com/sedm0784/vim-astronomer

Alternatively you could use a plugin manager such as [Vundle][vundle]. You
could even copy all the files directly into your `.vim` directory, but you
really shouldn't. Seriously, don't do that.

[pathogen]: https://github.com/tpope/vim-pathogen
[vundle]: https://github.com/gmarik/Vundle.vim

## How do I use Astronomer?

Once installed, Astronomer gets to work immediately, TIRELESSLY scanning files
as you open them, and requiring no further input from you, the user. There
are, however, are a handful of tweaks and tricks you can perform. Eager
astronomers will want to peruse `:help astronomer` for full details of the
delights within.

## Ugh, Astronomer is terrible; I hate it.

I'm terribly sorry Astronomer has failed you!

If you would be so kind as to file a BUG REPORT and send me an example of a
file where you think Astronomer's work is LACKLUSTRE, I will stop at NOTHING
to improve Astronomer until it works as well for you as it does for me.

## I will do nothing of the kind!

In that case, maybe you would be happier with one of Astronomer's DASTARDLY
competitors:

- The aforementioned [sleuth.vim](https://github.com/tpope/vim-sleuth)
- A plugin by Ciaran McCreesh that predates both sleuth.vim and Astronomer:
  [DetectIndent](https://github.com/ciaranm/detectindent)

I haven't tried either of these myself, but maybe they will be more to your
liking.
