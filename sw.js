self.addEventListener("push", (event) => {
  let data = {};

  try {
    data = event.data ? event.data.json() : {};
  } catch {
    data = {
      body: event.data ? event.data.text() : "Tenés una actualización."
    };
  }

  const options = {
    body: data.body || "Hay novedades en un pedido.",
    icon: "./logo.png",
    data: { url: data.url || "./" },
    tag: data.tag || undefined
  };

  event.waitUntil(
    self.registration.showNotification(
      data.title || "Distribuidora SGV",
      options
    )
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  event.waitUntil((async () => {
    const target = new URL(
      event.notification.data?.url || "./",
      self.registration.scope
    );

    if (target.origin !== self.location.origin) return;

    const windows = await clients.matchAll({
      type: "window",
      includeUncontrolled: true
    });

    for (const client of windows) {
      if (client.url.startsWith(self.registration.scope)) {
        await client.focus();
        client.navigate(target.href);
        return;
      }
    }

    await clients.openWindow(target.href);
  })());
});
