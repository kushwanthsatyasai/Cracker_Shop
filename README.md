# Cracker Shop Pro - Flutter App with Supabase

A comprehensive Flutter application for managing a cracker shop business, featuring inventory management, billing, and user authentication powered by Supabase.

## Features

- 🔐 **User Authentication & Authorization**
  - Secure login/signup with Supabase Auth
  - Role-based access control (Admin/Biller)
  - User profile management

- 📦 **Inventory Management**
  - Product catalog with categories
  - Stock quantity tracking
  - Stock movement history
  - Product CRUD operations

- 🧾 **Billing System**
  - Create and manage bills
  - Customer information tracking
  - Multiple payment methods
  - Bill history and search

- 📊 **Dashboard & Analytics**
  - Sales overview
  - Revenue tracking
  - Bill statistics
  - Stock alerts

## Tech Stack

- **Frontend**: Flutter 3.8+
- **Backend**: Supabase (PostgreSQL + Auth + Real-time)
- **State Management**: Provider
- **Database**: PostgreSQL with Row Level Security (RLS)

## Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK 3.8.1 or higher
- Supabase account
- Git

## Installation & Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd cracker_shop
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Supabase Setup

Follow the detailed setup guide in [SUPABASE_SETUP.md](SUPABASE_SETUP.md) to:

1. Create a Supabase project
2. Set up the database schema
3. Configure Row Level Security (RLS)
4. Get API credentials

### 4. Configure Supabase Credentials

Update `lib/config/supabase_config.dart` with your Supabase credentials:

```dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const String serviceRoleKey = 'YOUR_SUPABASE_SERVICE_ROLE_KEY';
}
```

### 5. Run the Application

```bash
flutter run
```

## Database Schema

The app uses the following database structure:

### Tables

- **profiles**: User profiles and roles
- **products**: Product catalog and inventory
- **bills**: Bill headers and metadata
- **bill_items**: Individual items in bills
- **stock_movements**: Stock transaction history

### Key Relationships

- Users (profiles) create bills
- Bills contain multiple bill items
- Products are referenced in bill items and stock movements
- Stock movements track inventory changes

## Project Structure

```
lib/
├── config/
│   └── supabase_config.dart      # Supabase configuration
├── models/
│   ├── user.dart                 # User model
│   ├── product.dart              # Product model
│   ├── bill.dart                 # Bill and BillItem models
│   └── stock_movement.dart       # Stock movement model
├── providers/
│   └── auth_provider.dart        # Authentication state management
├── screens/
│   ├── login_screen.dart         # Login interface
│   ├── dashboard_screen.dart     # Admin dashboard
│   ├── product_selection_screen.dart # Product selection
│   ├── billing_screen.dart       # Bill creation
│   ├── inventory_screen.dart     # Inventory management
│   └── ...                       # Other screens
├── services/
│   ├── auth_service.dart         # Authentication service
│   ├── product_service.dart      # Product management
│   └── bill_service.dart         # Billing operations
├── theme/
│   └── app_theme.dart            # App styling
└── widgets/
    └── logout_button.dart        # Reusable components
```

## Usage

### Authentication

1. **Login**: Use your Supabase user credentials
2. **Role Assignment**: Users are assigned roles (admin/biller) during signup
3. **Session Management**: Automatic session persistence

### Admin Features

- View all bills and users
- Manage product inventory
- Access analytics dashboard
- Stock management

### Biller Features

- Create bills for customers
- Select products and quantities
- Process payments
- View bill history

## Security Features

- **Row Level Security (RLS)**: Database-level access control
- **Role-based Access**: Different permissions for admin/biller roles
- **Secure Authentication**: Supabase Auth with JWT tokens
- **Data Validation**: Input validation and sanitization

## API Endpoints

The app interacts with Supabase through the following operations:

- **Authentication**: Sign in, sign up, sign out
- **Products**: CRUD operations with stock management
- **Bills**: Create, read, update with items
- **Profiles**: User profile management
- **Stock Movements**: Inventory transaction tracking

## Troubleshooting

### Common Issues

1. **Connection Errors**
   - Verify Supabase URL and API keys
   - Check internet connectivity
   - Ensure Supabase project is active

2. **Authentication Issues**
   - Verify user exists in Supabase Auth
   - Check user profile in profiles table
   - Ensure RLS policies are correct

3. **Database Errors**
   - Verify schema setup
   - Check RLS policies
   - Test queries in Supabase SQL Editor

### Debug Steps

1. Check Flutter console for error messages
2. Verify Supabase Dashboard → Logs
3. Test database queries manually
4. Check RLS policy configuration

## Development

### Adding New Features

1. **Models**: Create data models in `lib/models/`
2. **Services**: Implement business logic in `lib/services/`
3. **Screens**: Add UI components in `lib/screens/`
4. **Providers**: Manage state in `lib/providers/`

### Testing

   ```bash
flutter test
   ```

### Building for Production

```bash
flutter build apk --release
flutter build ios --release
flutter build web --release
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Documentation**: [SUPABASE_SETUP.md](SUPABASE_SETUP.md)
- **Supabase Docs**: [supabase.com/docs](https://supabase.com/docs)
- **Flutter Docs**: [flutter.dev/docs](https://flutter.dev/docs)

## Changelog

### v1.0.0
- Initial release with Supabase integration
- User authentication and authorization
- Product and inventory management
- Billing system
- Admin dashboard
- Row Level Security implementation
