# Dotfiles

My dotfiles, managed by [chezmoi](https://www.chezmoi.io/).

## Bootstrap

`~/Code/chef` comes in as a private git-repo external, so give git GitHub credentials before the first apply:

```sh
gh auth login && gh auth setup-git
chezmoi init --apply marc-mrt/dotfiles
```
