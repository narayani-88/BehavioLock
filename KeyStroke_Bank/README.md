# KetStroke Bank

A comprehensive banking application built with Flutter that provides a complete banking experience with modern UI/UX.

## Features

### Core Banking Features
- **Account Management**: Add, manage, and delete bank accounts
- **Transaction Management**: Send, receive, and transfer money between accounts
- **Card Management**: Add and manage debit, credit, and forex cards
- **QR Code Integration**: Generate and scan QR codes for payments
- **Transaction History**: View detailed transaction history with filtering

### New Features (Latest Update)

#### PayPal Support
- **PayPal Network**: Added PayPal as a supported card network
- **PayPal Cards**: Users can now add PayPal cards alongside traditional networks (Visa, Mastercard, Amex, etc.)
- **Network Selection**: Choose from multiple card networks including PayPal in the card addition flow

#### Pay by Card Functionality
- **Card Payments**: New dedicated "Pay by Card" screen for making payments using saved cards
- **Merchant Selection**: Predefined list of popular merchants (Amazon, Flipkart, Swiggy, etc.) with custom merchant option
- **Payment Processing**: Secure payment processing with balance validation
- **Transaction Recording**: All card payments are recorded in transaction history
- **Quick Access**: "Pay by Card" button available in both dashboard quick actions and My Cards screen

### User Interface
- **Modern Design**: Clean, intuitive interface with Material Design 3
- **Responsive Layout**: Optimized for various screen sizes
- **Dark Mode Support**: Toggle between light and dark themes
- **Accessibility**: Built with accessibility best practices

### Security Features
- **Local Storage**: Secure local storage for user data
- **Authentication**: User authentication and session management
- **Data Validation**: Comprehensive input validation and error handling

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code
- Android Emulator or Physical Device

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ketstrokebank.git
cd ketstrokebank/KeyStroke_Bank
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run
```

## Project Structure

```
lib/
├── constants/
│   └── app_theme.dart          # App theme and styling
├── models/
│   ├── bank_account_model.dart # Bank account data model
│   ├── card_model.dart         # Card data model
│   ├── transaction_model.dart  # Transaction data model
│   └── user_model.dart         # User data model
├── screens/
│   ├── accounts/               # Account management screens
│   ├── auth/                   # Authentication screens
│   ├── dashboard/              # Main dashboard
│   ├── profile/                # Profile and settings screens
│   ├── qr/                     # QR code functionality
│   └── transactions/           # Transaction screens
├── services/
│   ├── api_service.dart        # API communication
│   ├── auth_service.dart       # Authentication service
│   ├── bank_account_service.dart # Account management
│   ├── card_service.dart       # Card management
│   ├── profile_service.dart    # Profile management
│   ├── settings_service.dart   # App settings
│   └── transaction_service.dart # Transaction management
└── main.dart                   # App entry point
```

## Usage

### Adding Cards
1. Navigate to "My Cards" from the dashboard
2. Tap "ADD NEW CARD"
3. Choose card type (Debit, Credit, or Forex)
4. Select network (Visa, Mastercard, Amex, PayPal, etc.)
5. Enter card details and save

### Making Payments
1. **From Dashboard**: Tap "Pay by Card" in Quick Actions
2. **From My Cards**: Tap "PAY BY CARD" button
3. Select a card with sufficient balance
4. Enter payment amount
5. Choose merchant or enter custom merchant name
6. Add optional description
7. Tap "PAY NOW" to process payment

### Managing Accounts
1. Navigate to "My Accounts" section
2. Add new accounts or manage existing ones
3. View account balances and transaction history
4. Set primary account for default operations

## Supported Card Networks

- **Visa**: Traditional Visa cards
- **Mastercard**: Mastercard network cards
- **American Express (Amex)**: Amex cards
- **Discover**: Discover network cards
- **RuPay**: Indian RuPay cards
- **UnionPay**: Chinese UnionPay cards
- **PayPal**: PayPal cards and accounts

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and questions, please open an issue in the GitHub repository or contact the development team.

## Changelog

### Latest Update
- ✅ Added PayPal network support
- ✅ Implemented Pay by Card functionality
- ✅ Added merchant selection for payments
- ✅ Enhanced card management with payment capabilities
- ✅ Updated UI with new payment options
- ✅ Added transaction recording for card payments

### Previous Updates
- Initial release with core banking features
- QR code integration
- Account management
- Transaction history
- User authentication
