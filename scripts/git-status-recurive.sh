#!/usr/bin/bash

{
	function R-() {
		test -d .git && {
			echo -e "[32m$(pwd)[0m";
			git status;
		}
		for SD in $(ls); {
			test -d $SD && {
				pushd $SD >/dev/null;
				R-;
				popd >/dev/null;
			}
		}
	}
	R-
}
