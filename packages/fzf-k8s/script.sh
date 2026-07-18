#!/usr/bin/env bash
# Interactive Kubernetes pod browser (namespace-scoped).
#
# Cluster-wide pod listing often isn't permitted, so this picks a namespace
# first, then browses pods within it. Pass a namespace as $1 to skip the picker.
#
# - Preview live-tails the selected pod's logs (all containers)
# - Enter: kubectl exec into the pod  |  CTRL-O: open logs in $EDITOR
# - CTRL-R: reload pod list  |  CTRL-/: cycle preview window

context=$(kubectl config current-context | sed 's/-context$//')

# Stage 1: choose a namespace (unless one was given as an argument).
ns="${1:-}"
if [ -z "$ns" ]; then
	ns=$(kubectl get namespaces -o name |
		sed 's|namespace/||' |
		fzf --info=inline --layout=reverse --prompt "$context ns> ") || exit 0
fi
[ -z "$ns" ] && exit 0

# Stage 2: browse pods within the chosen namespace.
# Without --all-namespaces the columns are NAME READY STATUS ..., so {1} = pod.
command="kubectl get pods --namespace $ns"
: | fzf \
	--info=inline --layout=reverse --header-lines=1 \
	--prompt "$context/$ns> " \
	--header $'╱ Enter (kubectl exec) ╱ CTRL-O (open log in editor) ╱ CTRL-R (reload) ╱\n\n' \
	--bind "start:reload:$command" \
	--bind "ctrl-r:reload:$command" \
	--bind 'ctrl-/:change-preview-window(80%,border-bottom|hidden|)' \
	--bind "enter:execute:kubectl exec -it --namespace $ns {1} -- bash > /dev/tty" \
	--bind "ctrl-o:execute:${EDITOR:-vim} <(kubectl logs --all-containers --namespace $ns {1}) > /dev/tty" \
	--preview-window up:follow \
	--preview "kubectl logs --follow --all-containers --tail=10000 --namespace $ns {1}"
