// Add a custom error handler function at the top of your script
const handleError = (stepName, error) => {
  console.error(`Error in step "${stepName}": ${error.message}`);
  // You can add additional reporting logic here
  // Immediately end the test
  process.exit(1);
};

// Helper function to check if element exists
async function elementExists(locator, timeout = 5000) {
  try {
    // Use a shorter timeout for checking existence
    await locator.waitFor({ state: 'attached', timeout });
    return true;
  } catch (error) {
    return false;
  }
}

// Modify your steps to use try/catch blocks
step('Login Step', async () => {
  try {
    await page.goto('https://onetimprod.cable.comcast.com/OneTimMvo/OrderStatus');
    await page.waitForURL('**/oauth2/**');
    
    // Create locators
    const emailField = page.getByPlaceholder('Enter UPN or Email');
    const nextButton = page.getByRole('button', { name: 'Next' });
    const passwordField = page.getByPlaceholder('Password');
    const signInButton = page.getByRole('button', { name: 'Sign in' });
    
    // Check if elements exist before interacting
    if (!await elementExists(emailField)) {
      throw new Error('Email field not found');
    }
    
    await emailField.click();
    await emailField.fill(params.onetim_user);
    
    if (!await elementExists(nextButton)) {
      throw new Error('Next button not found');
    }
    await nextButton.click();
    
    if (!await elementExists(passwordField)) {
      throw new Error('Password field not found');
    }
    await passwordField.click();
    await passwordField.fill(params.onetim_sec);
    
    if (!await elementExists(signInButton)) {
      throw new Error('Sign in button not found');
    }
    await signInButton.click();
  } catch (error) {
    handleError('Login Step', error);
  }
});

step('Order Status', async () => {
  try {
    await page.goto('https://onetimprod.cable.comcast.com/OneTimMvo/OrderStatus', { waitUntil: 'networkidle', timeout: 70000 });
    
    // Create the frame locators first
    const mainFrame = page.frameLocator('#frmMain');
    const popupFrame = mainFrame.frameLocator('#popup_CIF-1');
    
    // Create element locators
    const filterButton = mainFrame.getByRole('img', { name: 'Filter' });
    const hideDeletedCheckbox = popupFrame.locator('#chkHideDeleted');
    const hideNotAssignedCheckbox = popupFrame.locator('#chkHideNotAssigned');
    const applyButton = popupFrame.getByRole('button', { name: 'Apply' });
    
    // Check if main frame exists
    if (!await elementExists(mainFrame)) {
      throw new Error('Main frame (#frmMain) not found');
    }
    
    // Check if filter button exists before clicking
    if (!await elementExists(filterButton)) {
      throw new Error('Filter button not found');
    }
    await filterButton.click();
    
    // Check if popup frame exists after clicking filter
    if (!await elementExists(popupFrame)) {
      throw new Error('Popup frame (#popup_CIF-1) not found');
    }
    
    // Check for checkboxes and buttons
    if (!await elementExists(hideDeletedCheckbox)) {
      throw new Error('Hide Deleted checkbox not found');
    }
    await hideDeletedCheckbox.uncheck();
    
    if (!await elementExists(hideNotAssignedCheckbox)) {
      throw new Error('Hide Not Assigned checkbox not found');
    }
    await hideNotAssignedCheckbox.uncheck();
    
    if (!await elementExists(applyButton)) {
      throw new Error('Apply button not found');
    }
    await applyButton.click();
  } catch (error) {
    handleError('Order Status', error);
  }
});

step('Order Detail', async () => {
  try {
    // Create locators first
    const frame = page.frameLocator('#frmMain');
    const orderGrid = frame.locator('#orderGrid');
    
    // Check if main frame exists
    if (!await elementExists(frame)) {
      throw new Error('Main frame (#frmMain) not found');
    }
    
    // Check if order grid exists
    if (!await elementExists(orderGrid)) {
      throw new Error('Order grid not found');
    }
    
    // Wait for the grid to be visible with timeout
    await orderGrid.waitFor({ state: 'visible', timeout: 15000 });
    
    // Locate the first row
    const firstRow = frame.locator('.slick-row').first();
    if (!await elementExists(firstRow)) {
      throw new Error('No rows found in the grid');
    }
    
    // Wait for the row to be visible
    await firstRow.waitFor({ state: 'visible', timeout: 10000 });
    
    // Check if order cell exists
    const orderCell = firstRow.locator('.slick-cell.r2.alignRight');
    if (!await elementExists(orderCell)) {
      throw new Error('Order cell not found in the first row');
    }
    
    // Get the order number
    const orderNumber = await orderCell.textContent();
    if (!orderNumber) {
      throw new Error('Could not retrieve order number text');
    }
    
    // Check if the order number element exists before clicking
    const orderElement = frame.getByText(orderNumber.trim(), { exact: true });
    if (!await elementExists(orderElement)) {
      throw new Error(`Order element with text "${orderNumber.trim()}" not found`);
    }
    
    // Click on the order
    await orderElement.click();
  } catch (error) {
    handleError('Order Detail', error);
  }
});

step('Order Details Tabs', async () => {
  try {
    // Define tab locators
    const tabs = [
      { name: 'Lines', locator: page.getByRole('link', { name: 'Lines' }) },
      { name: 'Preempts', locator: page.getByRole('link', { name: 'Preempts' }) },
      { name: 'Totals', locator: page.getByRole('link', { name: 'Totals' }) },
      { name: 'Billing', locator: page.getByRole('link', { name: 'Billing', exact: true }) },
      { name: 'Traffic Options', locator: page.getByRole('link', { name: 'Traffic Options' }) },
      { name: 'Comments', locator: page.getByRole('link', { name: 'Comments' }) },
      { name: 'Approvals', locator: page.getByRole('link', { name: 'Approvals' }) }
    ];
    
    // Click each tab, checking for existence first
    for (const tab of tabs) {
      if (await elementExists(tab.locator)) {
        console.log(`Clicking on tab: ${tab.name}`);
        await tab.locator.click();
        // Add a small wait between tabs for UI to update
        await page.waitForTimeout(500);
      } else {
        console.warn(`Tab "${tab.name}" not found - skipping`);
        // Option 1: Skip missing tabs but continue
        // Option 2: Throw an error to stop the test
        // throw new Error(`Tab "${tab.name}" not found`);
      }
    }
  } catch (error) {
    handleError('Order Details Tabs', error);
  }
});

step('Logout Step', async () => {
  try {
    const logoutButton = page.getByTitle('Logout');
    
    if (!await elementExists(logoutButton)) {
      throw new Error('Logout button not found');
    }
    
    await logoutButton.click();
    
    // Optionally verify we're logged out by checking for login page or URL change
    try {
      await page.waitForURL('**/oauth2/**', { timeout: 10000 });
      console.log('Successfully logged out and redirected to login page');
    } catch (urlError) {
      console.warn('Could not verify successful logout via URL redirect');
      // We don't fail the test here, just log a warning
    }
  } catch (error) {
    handleError('Logout Step', error);
  }
});
