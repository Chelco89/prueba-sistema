self.addEventListener("push", (event) => {
  let data = {};

  try {
    data = event.data ? event.data.json() : {};
  } catch {
    data = {
      body: event.data ? event.data.text() : "Tenés una actualización."
    };
  }

  event.waitUntil(
    self.registration.showNotification(
      data.title || "Distribuidora SGV",
      {
        body: data.body || "Hay novedades en un pedido.",
        icon: "./logo.png",
        data: { url: data.url || "./" }
      }
    )
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const target = new URL(
    event.notification.data?.url || "./",
    self.registration.scope
  );

  if (target.origin !== self.location.origin) return;

  event.waitUntil(clients.openWindow(target.href));
});
