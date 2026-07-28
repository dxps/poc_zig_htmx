(() => {
  "use strict";

  function dismissToast(toast) {
    if (toast.dataset.dismissing === "true") return;
    toast.dataset.dismissing = "true";
    toast.classList.add("is-dismissing");
    toast.addEventListener("animationend", () => toast.remove(), { once: true });
  }

  function initializeToast(toast) {
    if (toast.dataset.toastReady === "true") return;
    toast.dataset.toastReady = "true";

    const timeout = Number(toast.dataset.timeout) || 5000;
    const timer = window.setTimeout(() => dismissToast(toast), timeout);

    toast.querySelector("[data-toast-close]")?.addEventListener("click", () => {
      window.clearTimeout(timer);
      dismissToast(toast);
    });
  }

  function initializeWithin(root) {
    if (!root) return;
    if (root.matches?.("[data-toast]")) initializeToast(root);
    root.querySelectorAll?.("[data-toast]").forEach(initializeToast);
  }

  document.addEventListener("DOMContentLoaded", () => initializeWithin(document));
  document.addEventListener("htmx:after:settle", (event) => initializeWithin(event.target));
})();
