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
// let socket = new Socket("/socket", {params: {token: csrfToken}})

// socket.connect()

// // Now that you are connected, you can join channels with a topic:
// let channel = socket.channel("dags:lobby", {})
// channel.join()
//   .receive("ok", resp => { console.log("Joined successfully", resp) })
//   .receive("error", resp => { console.log("Unable to join", resp) })


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

Hooks.DeleteDag = {
    mounted() {

    }
}

Hooks.DAGRunChart = {

    getData() {
        const tasksData = JSON.parse(this.el.getAttribute('run-tasks'))
        const tasksDeps = JSON.parse(this.el.getAttribute('run-task-deps'))

        let data = {};
        const tasks = Object.keys(tasksData)

        tasks.forEach(task => {
            const taskObject = tasksData[task]
            let color = 'grey';
            if (taskObject.status == "completed") {
                color = "green";
            } else if (taskObject.status == 'running') {
                color = 'orange'
            } else if (taskObject.status == 'failed') {
                color = 'red'
            }
            data[task] = { 'child': task, 'color': color }
        })

        const parents = Object.keys(tasksDeps);
        parents.forEach(p => {
            const children = tasksDeps[p]
            children.forEach(child => {
                data[child].parent = p;
            });
        })
        return data;
    },
    buildSvg() {
        const svg = d3.select('#d3-run-chart-container')
            .append('svg').attr('width', '100%')
            .attr('height', 600)
            .append('g')
            .attr('transform', 'translate(50,50)')
        return svg;
    },
    addConnections(svg, links) {
        const orientation = d3.linkHorizontal()
            .x((d) => { return d.y; })
            .y((d) => { return d.x; });
        const connections = svg.append("g").selectAll("path").data(links);
        connections
            .enter()
            .append("path")
            .attr("d", orientation)
            .attr('stroke', 'orange')
            .attr('stroke-width', 2)

        return connections;
    },
    addNodes(svg, nodes) {
        const circles = svg
            .append("g")
            .selectAll("circle")
            .data(nodes)

        //placing the circles
        circles
            .enter()
            .append("circle")
            .attr("cx", (d) => {
                return d.y;
            })
            .attr("cy", (d) => {
                return d.x;
            })
            .attr("r", 10)
            .attr('fill', (d) => d.data.color)
            .on("click", (d) => {
                this.pushEvent('get-task-info', {
                    'task_id': d.data.child,
                    'dag_id': this.dag_id,
                    'run_id': this.run_id
                }, (reply, ref) => {
                    let html = reply.html;
                    $('#task-content-name').html(html);
                    $('#task-details').modal('show');
                })
            })
            .append("text");
        return circles;
    },
    addLabels(svg, nodes) {
        const labels = svg.append("g").selectAll("text").data(nodes);
        labels
            .enter()
            .append("text")
            .text((d) => {
                return d.data.child;
            })
            .attr("x", (d) => {
                return d.y - 15;
            })
            .attr("y", (d) => {
                return d.x - 15;
            });
        return labels;
    },
    renderD3() {
        const new_data = this.getData();
        const svg = this.buildSvg();
        const treeLayout = d3.tree().size([600, 600])

        const dataStructure = d3.stratify()
            .id((d) => { return d.child; })
            .parentId((d) => { return d.parent; })
            (Object.values(new_data))
        const information = treeLayout(dataStructure);

        this.addConnections(svg, information.links())

        this.addNodes(svg, information.descendants());

        //labels
        this.addLabels(svg, information.descendants())
    },
    renderGraph() {
        let data = JSON.parse(this.el.getAttribute('run-data'))
        let tasks_data = JSON.parse(this.el.getAttribute('run-tasks'))
        let tasks_deps = JSON.parse(this.el.getAttribute('run-task-deps'))

        console.log(data);
        console.log(tasks_data);
        console.log(tasks_deps);

        let tasks = Object.keys(tasks_data)
        let taskNodes = []
        for (let i in tasks) {
            let task = tasks[i]
            let taskNode = {
                id: task, label: task,
                shape: 'circle',
                font: {
                    color: 'white'
                },
                size: 50
            }
            let color = null;
            let taskObject = tasks_data[task]
            console.log('Task: ', task, taskObject.status);
            if (taskObject.status == "completed") {
                color = "green";
            } else if (taskObject.status == 'running') {
                color = 'orange'
            } else if (taskObject.status == 'failed') {
                color = 'red'
            } else {
                color = 'grey'
            }

            taskNode.color = color;
            taskNodes.push(taskNode)
        }
        let nodes = new vis.DataSet(taskNodes);


        tasks = Object.keys(tasks_deps)

        let edgesList = []
        for (let i in tasks) {
            let task = tasks[i]
            let deps = tasks_deps[task]
            for (let dep in deps) {
                edgesList.push({
                    from: task, to: deps[dep]
                })
            }
        }
        console.log(edgesList)
        let edges = new vis.DataSet(edgesList);
        let container = document.getElementById("run-chart-container");
        let nodesData = {
            nodes: nodes,
            edges: edges,
        };
        let options = {
            layout: {
                hierarchical: {
                    direction: "LR",
                    sortMethod: "directed"
                }
            },
        };

        this.network = new vis.Network(container, nodesData, options);

    },
    beforeUpdate() {
        const isOpen = $("#task-details").data('bs.modal')?._isShown;
        console.log('Is opened: ', isOpen);
        $('#task-details').modal('hide');
        if (isOpen) {
            // re-open modal
        }
    },
    mounted() {
        this.handleEvent("update_dags", (data) => {
            console.log(data)
        });
        this.dag_id = this.el.getAttribute('dag-id')
        this.run_id = this.el.getAttribute('run-id')
        this.renderd3();
    },
    updated() {
        this.renderD3();
    }
}
Hooks.Chart = {
    mounted() {
        console.log('Mounted', this);
        this.handleEvent("update_dags", (data) => {
            console.log(data)
        })
        let containers = document.getElementsByClassName("run-graph");
        console.log(containers)
        for (let i = 0; i < containers.length; i++) {
            let containerId = containers[i].getAttribute('id');
            let data = JSON.parse(containers[i].getAttribute('data'))

            console.log(containerId, data);

            let tasks = Object.keys(data)
            let taskNodes = []
            for (let i in tasks) {
                let task = tasks[i]
                console.log('Task: ', tasks[i]);
                let color = null;
                let taskObject = data[task]
                if (taskObject.status === "completed") {
                    color = "green";
                }
                taskNodes.push({
                    id: task, label: task,
                    color: color
                })
            }
            let nodes = new vis.DataSet(taskNodes);
            let edges = new vis.DataSet();
            let container = document.getElementById(containerId);
            let nodesData = {
                nodes: nodes,
                edges: edges,
            };
            let options = {};
            let network = new vis.Network(container, nodesData, options);
        }
    },
    updated(event) {
        let containers = document.getElementsByClassName("run-graph");
        console.log(containers)
        for (let i = 0; i < containers.length; i++) {
            let containerId = containers[i].getAttribute('id');
            let data = JSON.parse(containers[i].getAttribute('data'))

            console.log(containerId, data);

            let tasks = Object.keys(data)
            let taskNodes = []
            for (let task in tasks) {
                taskNodes.push({
                    id: task, label: task
                })
            }
            let nodes = new vis.DataSet(taskNodes);
            let edges = new vis.DataSet();
            let container = document.getElementById(containerId);
            let nodesData = {
                nodes: nodes,
                edges: edges,
            };
            let options = {};
            let network = new vis.Network(container, nodesData, options);
        }
    }
}
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
    },
    mounted() {
        console.log('aaaa');
    }
})


// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start());
window.addEventListener("phx:page-loading-stop", info => NProgress.done());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
