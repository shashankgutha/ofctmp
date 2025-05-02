step('Order Detail', async () => {
  await page.waitForSelector('#frmMain', { timeout: 5000 });
  const frame = await page.frameLocator('#frmMain');
  const orderGrid = frame.locator('#orderGrid');
  await orderGrid.waitFor({ state: 'attached', timeout: 5000 });
  const firstRow = frame.locator('.slick-row').first();
  await firstRow.waitFor({state: 'attached', timeout: 5000 });
  const orderCell = await firstRow.locator('.slick-cell.r2.alignRight');
  await orderCell.waitFor({state: 'attached', timeout: 5000 });
  const orderNumber = await orderCell.textContent();
  
  // Modified click action with custom headers
  await page.route('**/*', async route => {
    const headers = {
      ...route.request().headers(),
      'Host': 'your-host-value'  // Add your specific host header here
      // Add any other headers you need from your F5 BIG-IP configuration
    };
    await route.continue({ headers });
  });
  
  await page.frameLocator('#frmMain').getByText(orderNumber.trim(), { exact: true }).click();
});
