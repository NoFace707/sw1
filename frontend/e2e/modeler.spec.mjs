import { expect, test } from "@playwright/test";

const backendPort = process.env.E2E_BACKEND_PORT || "8001";
const apiBase = `http://127.0.0.1:${backendPort}`;

async function register(request, suffix) {
  const email = `e2e-${suffix}-${Date.now()}-${Math.random().toString(16).slice(2)}@example.test`;
  const response = await request.post(`${apiBase}/api/auth/register/`, { data: { first_name: suffix, last_name: "E2E", email, password: "E2E-local-password-123!" } });
  expect(response.ok()).toBeTruthy();
  return { ...(await response.json()), email };
}

async function seedSession(context, session) {
  await context.addInitScript(({ value }) => {
    sessionStorage.setItem("auth_storage_mode", "session");
    sessionStorage.setItem("current_user", JSON.stringify(value.user));
    sessionStorage.setItem("auth_access_token", value.access);
    sessionStorage.setItem("auth_refresh_token", value.refresh);
  }, { value: session });
}

async function openProject(page, projectId) {
  await page.goto(`/projects/${projectId}`);
  await expect(page.getByText("Colaboración: online")).toBeVisible({ timeout: 15_000 });
  await expect(page.getByRole("combobox", { name: "Diagrama actual" })).toHaveValue(/.+/);
}

test("dos clientes crean, renombran y eliminan cambios sin refrescar", async ({ browser, request }) => {
  const owner = await register(request, "owner");
  const collaborator = await register(request, "collaborator");
  const projectResponse = await request.post(`${apiBase}/api/modeling/projects/`, {
    headers: { Authorization: `Bearer ${owner.access}` },
    data: { name: "E2E Collaboration", create_initial_diagram: true },
  });
  expect(projectResponse.ok()).toBeTruthy();
  const project = await projectResponse.json();
  const inviteResponse = await request.post(`${apiBase}/api/modeling/projects/${project.id}/invites/create/`, {
    headers: { Authorization: `Bearer ${owner.access}` },
    data: { role: "editor", max_uses: 1 },
  });
  const invite = await inviteResponse.json();
  const joinResponse = await request.post(`${apiBase}/api/modeling/projects/join/`, {
    headers: { Authorization: `Bearer ${collaborator.access}` },
    data: { code: invite.code },
  });
  expect(joinResponse.ok()).toBeTruthy();

  const ownerContext = await browser.newContext();
  const collaboratorContext = await browser.newContext();
  await seedSession(ownerContext, owner);
  await seedSession(collaboratorContext, collaborator);
  const ownerPage = await ownerContext.newPage();
  const collaboratorPage = await collaboratorContext.newPage();
  await Promise.all([openProject(ownerPage, project.id), openProject(collaboratorPage, project.id)]);

  await ownerPage.getByRole("button", { name: /Clase$/ }).first().click();
  await expect(collaboratorPage.getByText("Clase 1", { exact: true })).toBeVisible({ timeout: 10_000 });

  const collaboratorNode = collaboratorPage.locator(".react-flow__node-uml").first();
  await collaboratorNode.dblclick();
  const inlineName = collaboratorNode.getByLabel("Nombre de la figura");
  await inlineName.fill("Pedido");
  await inlineName.press("Enter");
  await expect(ownerPage.getByText("Pedido", { exact: true })).toBeVisible({ timeout: 10_000 });

  await collaboratorNode.click();
  await collaboratorPage.keyboard.press("Delete");
  await expect(ownerPage.getByText("Pedido", { exact: true })).toHaveCount(0, { timeout: 10_000 });

  await ownerContext.setOffline(true);
  await expect(ownerPage.locator("footer").getByText(/Offline/).first()).toBeVisible();
  await ownerContext.setOffline(false);
  await expect(ownerPage.getByText("Colaboración: online")).toBeVisible({ timeout: 15_000 });

  await ownerContext.close();
  await collaboratorContext.close();
});

test("un lector abre el lienzo pero no puede crear figuras", async ({ browser, request }) => {
  const owner = await register(request, "reader-owner");
  const reader = await register(request, "reader");
  const project = await (await request.post(`${apiBase}/api/modeling/projects/`, { headers: { Authorization: `Bearer ${owner.access}` }, data: { name: "E2E Reader", create_initial_diagram: true } })).json();
  const invite = await (await request.post(`${apiBase}/api/modeling/projects/${project.id}/invites/create/`, { headers: { Authorization: `Bearer ${owner.access}` }, data: { role: "viewer", max_uses: 1 } })).json();
  expect((await request.post(`${apiBase}/api/modeling/projects/join/`, { headers: { Authorization: `Bearer ${reader.access}` }, data: { code: invite.code } })).ok()).toBeTruthy();

  const context = await browser.newContext();
  await seedSession(context, reader);
  const page = await context.newPage();
  await openProject(page, project.id);
  await page.getByRole("button", { name: /Clase$/ }).first().click();
  await expect(page.locator(".react-flow__node-uml")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Nuevo diagrama" })).toBeDisabled();
  await context.close();
});

test("la interfaz compacta inserta SVG real y persiste un conector unido", async ({ browser, request }) => {
  const owner = await register(request, "visual-owner");
  const projectResponse = await request.post(`${apiBase}/api/modeling/projects/`, {
    headers: { Authorization: `Bearer ${owner.access}` },
    data: { name: "E2E Visual", create_initial_diagram: true },
  });
  expect(projectResponse.ok()).toBeTruthy();
  const project = await projectResponse.json();
  const context = await browser.newContext({ viewport: { width: 1366, height: 768 } });
  await seedSession(context, owner);
  const page = await context.newPage();
  const badResponses = [];
  const pageErrors = [];
  page.on("response", (response) => { if (response.status() >= 400) badResponses.push(`${response.status()} ${response.url()}`); });
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await openProject(page, project.id);

  await expect(page.getByPlaceholder("Buscar figuras…")).toBeVisible();
  await expect(page.getByRole("button", { name: "Nuevo diagrama" })).toBeVisible();
  await expect(page.getByLabel("Nombre del proyecto")).toHaveCount(0);
  const canvas = page.locator(".react-flow");
  const ellipseButton = page.getByRole("button", { name: /Elipse$/ });
  const rectangleButton = page.getByRole("button", { name: /Rectángulo$/ }).first();
  await ellipseButton.dragTo(canvas, { targetPosition: { x: 90, y: 260 } });
  await rectangleButton.dragTo(canvas, { targetPosition: { x: 800, y: 260 } });
  await expect(page.locator('.react-flow__node-visual [data-shape="ellipse"] ellipse')).toHaveCount(1);
  await expect(page.locator(".react-flow__node-visual")).toHaveCount(2);

  await page.getByRole("button", { name: /^Flecha$/ }).click();
  const sourceHandle = page.locator(".react-flow__node-visual").nth(0).locator(".react-flow__handle-right");
  const targetHandle = page.locator(".react-flow__node-visual").nth(1).locator(".react-flow__handle-left");
  const sourceBox = await sourceHandle.boundingBox();
  const targetBox = await targetHandle.boundingBox();
  expect(sourceBox).toBeTruthy();
  expect(targetBox).toBeTruthy();
  await sourceHandle.dispatchEvent("click");
  await expect(page.locator("footer")).toContainText("Origen seleccionado");
  await targetHandle.dispatchEvent("click");
  await expect(page.locator(".react-flow__edge-modeler")).toHaveCount(1, { timeout: 10_000 });
  await page.reload();
  await expect(page.locator(".react-flow__edge-modeler")).toHaveCount(1, { timeout: 10_000 });
  expect(pageErrors).toEqual([]);
  expect(badResponses).toEqual([]);
  await context.close();
});

test("la paleta UML ampliada crea variantes semánticas con su geometría", async ({ browser, request }) => {
  const owner = await register(request, "uml-palette-owner");
  const project = await (await request.post(`${apiBase}/api/modeling/projects/`, {
    headers: { Authorization: `Bearer ${owner.access}` },
    data: { name: "E2E UML Palette", create_initial_diagram: true },
  })).json();
  const context = await browser.newContext({ viewport: { width: 1366, height: 768 } });
  await seedSession(context, owner);
  const page = await context.newPage();
  await openProject(page, project.id);

  await expect(page.getByText("Clase abstracta", { exact: true })).toBeVisible();
  await expect(page.getByText("Clase con atributos", { exact: true })).toBeVisible();
  await expect(page.getByText("Actor", { exact: true })).toBeVisible();
  await expect(page.getByText("Enumeración", { exact: true })).toBeVisible();
  await page.getByText("Clase con atributos", { exact: true }).click();
  const classifierWithFields = page.locator(".react-flow__node-uml").first();
  await expect(classifierWithFields.getByText("+ atributo1: Tipo", { exact: true })).toBeVisible();
  await expect(classifierWithFields.getByText("+ atributo3: Tipo", { exact: true })).toBeVisible();
  await classifierWithFields.click();
  const firstAttribute = page.getByRole("textbox", { name: "Atributo 1" });
  await firstAttribute.fill("+ codigo: UUID");
  await firstAttribute.press("Enter");
  await expect(page.locator("footer")).toContainText("Atributos guardados");
  await page.getByRole("button", { name: "Añadir atributo" }).click();
  await expect(page.getByRole("textbox", { name: "Atributo 4" })).toBeVisible();
  await expect(page.locator("footer")).toContainText("Atributos guardados");
  await page.getByRole("button", { name: "Eliminar atributo 2" }).click();
  await expect(page.getByRole("textbox", { name: "Atributo 4" })).toHaveCount(0);
  await expect(page.locator("footer")).toContainText("Atributos guardados");
  await page.reload();
  await expect(page.getByText("+ codigo: UUID", { exact: true })).toBeVisible();
  await page.getByText("Clase abstracta", { exact: true }).click();
  await expect(page.locator(".react-flow__node-uml .italic")).toHaveCount(1);

  await page.getByRole("button", { name: "Nuevo diagrama" }).click();
  await page.getByLabel("Nombre").fill("Estados completos");
  await page.getByLabel("Tipo").selectOption("state_machine");
  await page.getByRole("button", { name: "Crear", exact: true }).click();
  await expect(page.getByText("Elección", { exact: true })).toBeVisible();
  await expect(page.getByText("Historia profunda", { exact: true })).toBeVisible();
  await expect(page.getByText("Terminación", { exact: true })).toBeVisible();
  await page.getByText("Elección", { exact: true }).click();
  await expect(page.locator('.react-flow__node-uml [data-shape="diamond"]')).toHaveCount(1);
  await context.close();
});
