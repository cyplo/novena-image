#
# Utilities
function fail() { echo "$@" 1>&2; return 1; }
function stat() { command stat -L -c '%F' "$@"; }

# to_bytes provides a tool to convert human
# inputed device sizes into raw bytes.
function to_bytes() {
	awk '/[0-9]$/{print $1;next};\
		/[tT]$/{printf "%u\n", $1*(1024**4);next}; \
		/[gG]$/{printf "%u\n", $1*(1024**3);next}; \
		/[mM]$/{printf "%u\n", $1*(1024**2);next}; \
		/[kK]$/{printf "%u\n", $1*1024;next}' <<<"$@"
}
