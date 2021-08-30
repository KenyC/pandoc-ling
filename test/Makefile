YAML_FILE=pandoc.yaml

all: examples

%.html: %.md ../pandoc-ling.lua
	pandoc -d $(YAML_FILE) --from=markdown --to=html $< --output=$@

EXAMPLE_MD_FILES=$(wildcard examples/*.md)
EXAMPLE_HTML_FILES=$(EXAMPLE_MD_FILES:%.md=%.html)
examples: $(EXAMPLE_HTML_FILES)


clean:
	rm -f $(EXAMPLE_HTML_FILES)
