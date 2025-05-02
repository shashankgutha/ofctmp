step('Call API with Authorization Header', async () => {
  // Set Host header for load balancer routing
  await page.setExtraHTTPHeaders({
    'Host': 'target01.example.com'  // Replace with your specific target host
  });
  
  // For direct API calls, use Playwright's API request feature
  const apiContext = await page.context().request;
  
  // Make an API call with authorization header
  const apiResponse = await apiContext.fetch('https://your-api-endpoint.com/path', {
    method: 'GET', // or 'POST', 'PUT', etc. as needed
    headers: {
      'Authorization': 'Bearer your-auth-token-here',
      // The Host header set above will be included automatically
    }
  });
  
  // Check response status and abort if not 200
  const statusCode = apiResponse.status();
  console.log('Response status:', statusCode);
  
  if (statusCode !== 200) {
    const responseText = await apiResponse.text();
    console.error(`API call failed with status ${statusCode}: ${responseText}`);
    throw new Error(`API call failed with status ${statusCode}. Aborting test.`);
  }
  
  // If we reach here, status is 200, so continue
  const responseData = await apiResponse.json();
  console.log('Response data:', responseData);
  
  // Continue with your test using the API response data
  // ...
});
