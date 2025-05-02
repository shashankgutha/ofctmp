step('Check Headers with Direct Navigation and Status Check', async () => {
  // Set the headers you want to test
  await page.setExtraHTTPHeaders({
    'Host': 'target01.example.com',
    'Authorization': 'Bearer your-auth-token-here'
  });
  
  // Navigate to the URL - this will use the headers we just set
  const response = await page.goto('https://your-api-endpoint.com/path', {
    waitUntil: 'networkidle',  // Wait until network is idle
    timeout: 30000  // 30 second timeout
  });
  
  // Get the status directly from the response
  const statusCode = response.status();
  console.log('Response status:', statusCode);
  
  // Check if status is 200 (success)
  if (statusCode !== 200) {
    console.error(`Navigation failed with status ${statusCode}`);
    throw new Error(`Navigation failed with status ${statusCode}. Headers may not be working correctly. Aborting test.`);
  }
  
  console.log('Successfully received status 200. Headers are working correctly.');
  
  // Continue with the rest of your test...
});
