// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"
import {
    Socket
} from "phoenix"
import NProgress from "nprogress"
import {
    LiveSocket
} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {};
Hooks.AddDag = {
    mounted() {
        const hook = this;
        this.el.onclick = (event) => {
            event.preventDefault();
            const dagId = prompt("Enter Dag name");
            hook.pushEvent("add_dag", {
                id: dagId
            });
        };
    }
};

Hooks.RunDag = {
    mounted() {
        const hook = this;
        this.el.onclick = (event) => {
            event.preventDefault();
            const dagId = this.el.getAttribute('dag-id');
            
            hook.pushEvent("run_dag", {
                id: dagId
            });
        };
    }
};

Hooks.ResumeDag = {
    mounted() {
        const hook = this;
        this.el.onclick = (event) => {
            event.preventDefault();
            const dagId = this.el.getAttribute('dag-id');
            const runId = this.el.getAttribute('run-id');
            hook.pushEvent("resume_dag", {
                run_id: runId,
                dag_id: dagId
            });
        };
    }
};
Hooks.StopDag = {
    mounted() {
        const hook = this;
        this.el.onclick = (event) => {
            event.preventDefault();
            const dagId = this.el.getAttribute('dag-id');
            const runId = this.el.getAttribute('run-id');
            hook.pushEvent("stop_dag", {
                run_id: runId,
                dag_id: dagId
            });
        };
    }
};
Hooks.PhoneNumber = {
    mounted() {
        this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if (match) {
                this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
        });
    }
}
let liveSocket = new LiveSocket("/live", Socket, {
    hooks: Hooks,
    params: {
        _csrf_token: csrfToken
    }
})

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start());
window.addEventListener("phx:page-loading-stop", info => NProgress.done());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
