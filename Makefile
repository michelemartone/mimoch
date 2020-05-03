all: test README.md

test:
	./mimoch.sh -T

batch-test:
	. /etc/profile.d/modules.sh ; ./mimoch.sh -T

r: README.md

README.md: ./mimoch.sh
	./mimoch.sh -h -h | sed 's/^//g' > $@
