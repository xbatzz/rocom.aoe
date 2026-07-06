import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";
import { registerServiceWorker } from "./registerServiceWorker";
import "./style.css";

const app = createApp(App);

app.use(router);

app.mount("#app");

registerServiceWorker();
