step('Navigate to URL with Headers and Check Status', async () => {
  // Set both Host and Authorization headers
  await page.setExtraHTTPHeaders({
    'Host': 'target01.example.com',
    'Authorization': 'Bearer your-auth-token-here'
  });
  
  // Create a response promise before navigation
  const responsePromise = page.waitForResponse(response => {
    return response.url().includes('your-api-endpoint.com/path');
  });
  
  // Navigate to the URL
  await page.goto('https://your-api-endpoint.com/path');
  
  // Wait for the response
  const response = await responsePromise;
  
  // Check response status and abort if not 200
  const statusCode = response.status();
  console.log('Response status:', statusCode);
  
  if (statusCode !== 200) {
    console.error(`Navigation failed with status ${statusCode}`);
    throw new Error(`Navigation failed with status ${statusCode}. Aborting test.`);
  }
  
  // If status is 200, continue with the test
  console.log('Navigation successful with status 200');
  
  // Continue with your test...
  // For example, verify elements on the page
  await page.waitForSelector('#some-element', { timeout: 5000 });
});
