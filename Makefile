all: test README.md

test:
	./mimoch.sh -T

batch-test:
	. /etc/profile.d/modules.sh ; ./mimoch.sh -T

r: README.md

README.md: ./mimoch.sh
	./mimoch.sh -h -h | sed 's/^//g' > $@

sc:
	shellcheck -e SC2006,SC1090,SC2185"",SC1117,SC2006,SC2046,SC2086,SC2069,SC2155,SC2162,SC2230 -f gcc mimoch.sh
