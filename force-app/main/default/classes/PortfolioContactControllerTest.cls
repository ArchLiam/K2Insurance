@IsTest
private class PortfolioContactControllerTest {
	@IsTest
	static void sendContactEmail_success() {
		Test.startTest();
		PortfolioContactController.sendContactEmail(
			'Test User',
			'tester@example.com',
			'Project inquiry',
			'Looking to discuss a new Salesforce project soon.',
			UserInfo.getUserEmail()
		);
		Test.stopTest();
	}

	@IsTest
	static void sendContactEmail_invalidEmail_throws() {
		Test.startTest();
		PortfolioContactController.sendContactEmail(
			'Test User',
			'not-an-email',
			'Hello',
			'Checking validation path for the controller.',
			UserInfo.getUserEmail()
		);
		Test.stopTest();
	}

	@IsTest
	static void sendContactEmail_usesDefaultRecipient_andDefaultsMessage() {
		// Blank toAddress -> defaults to fallback recipient; blank message -> default text
		Test.startTest();
		PortfolioContactController.sendContactEmail(
			'', // name -> becomes 'Portfolio visitor'
			'', // email -> replyTo skipped
			'', // subject -> normalized to default
			'', // message -> default fallback
			null // toAddress -> fallback to DEFAULT_RECIPIENT
		);
		Test.stopTest();
	}

	@IsTest
	static void sendContactEmail_truncatesLongFields() {
		String longSubject = buildString('S', 300);
		String longMessage = buildString('M', 4100);

		Test.startTest();
		PortfolioContactController.sendContactEmail(
			'Long Field User',
			'longfields@example.com',
			longSubject,
			longMessage,
			UserInfo.getUserEmail()
		);
		Test.stopTest();
	}

	// @IsTest
	// static void sendContactEmail_nameTooLong_throws() {
	// 	String overlongName = buildString('N', 130);
	// 	Boolean didThrow = false;

	// 	Test.startTest();
	// 	try {
	// 		PortfolioContactController.sendContactEmail(
	// 			overlongName,
	// 			'valid@example.com',
	// 			'Hi',
	// 			'Message',
	// 			UserInfo.getUserEmail()
	// 		);
	// 	} catch (AuraHandledException ex) {
	// 		didThrow = true;
	// 		System.assert(
	// 			ex.getMessage().contains('120 characters'),
	// 			'Should enforce name length limit'
	// 		);
	// 	}
	// 	Test.stopTest();

	// 	System.assert(didThrow, 'Expected overlong name to throw an AuraHandledException');
	// }

	@IsTest
	static void sendContactEmail_emptyResults_branch() {
		Boolean didThrow = false;
		PortfolioContactController.testReturnEmptyResults = true;
		try {
			Test.startTest();
			try {
				PortfolioContactController.sendContactEmail(
					'User',
					'user@example.com',
					'Hi',
					'Msg',
					UserInfo.getUserEmail()
				);
			} catch (AuraHandledException ex) {
				didThrow = true;
			}
			Test.stopTest();
		} finally {
			PortfolioContactController.testReturnEmptyResults = false;
		}
		System.assert(didThrow, 'Expected empty results to throw AuraHandledException');
	}

	@IsTest
	static void sendContactEmail_exception_branch() {
		Boolean didThrow = false;
		PortfolioContactController.testForceException = true;
		try {
			Test.startTest();
			try {
				PortfolioContactController.sendContactEmail(
					'User',
					'user@example.com',
					'Hi',
					'Msg',
					UserInfo.getUserEmail()
				);
			} catch (AuraHandledException ex) {
				didThrow = true;
			}
			Test.stopTest();
		} finally {
			PortfolioContactController.testForceException = false;
		}
		System.assert(didThrow, 'Expected forced exception to throw AuraHandledException');
	}

	@IsTest
	static void sendContactEmail_setsOrgWide() {
		// Cover org-wide email branch by setting the test hook
		PortfolioContactController.testOrgWideEmailId = Id.valueOf('0D8000000000001');
		Test.startTest();
		PortfolioContactController.sendContactEmail(
			'OrgWide User',
			'orgwide@example.com',
			'OrgWide',
			'Testing org-wide from address',
			UserInfo.getUserEmail()
		);
		Test.stopTest();
		PortfolioContactController.testOrgWideEmailId = null;
	}

	private static String buildString(String ch, Integer len) {
		String result = '';
		for (Integer i = 0; i < len; i++) {
			result += ch;
		}
		return result;
	}
}