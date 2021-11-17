Readme for tests
==================================

The command `make` creates pdf's and html file from samples in src ; it also runs the html file and screenshots them. 

A typical workflow might look like this:

```bash
# Creates files and screenshots
make
# Save screenshots
make saveshots

# ... meanwhile, some changes are made to the lua filter

# Create new screenshots
make
# Compare them to previous version
make diff
# Diff images are stored in build/diff

```


## Requirements

For screenshots:

 - `odiffbin` on the PATH for image diff. Get it [here](https://github.com/dmtrKovalenko/odiff/releases)
 - Python with Selenium package installed.
 - Firefox and GeckoDriver 

To disable screenshots, change `SCREENSHOT` variable in `config.mk` 