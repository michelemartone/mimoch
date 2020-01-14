all: test README.md

test:
	./mimoch.sh -T

r: README.md

README.md: ./mimoch.sh
	./mimoch.sh -h | sed 's/^//g' > $@
