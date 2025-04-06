import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart'; // Required for Clipboard

// --- Configuration (kept outside the widget for clarity) ---

// Define the necessary YouTube scope
const List<String> _scopes = <String>[
  'https://www.googleapis.com/auth/youtube.readonly',
];

// Instantiate GoogleSignIn with the defined scopes
// You might want to manage this instance more globally in your app
// (e.g., using a service locator or provider) if other parts need it,
// but keeping it here works for a self-contained screen.
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: _scopes,
);

// --- Screen Widget ---

class YoutubeSignInScreen extends StatefulWidget {
  // You can add parameters here if needed, e.g., callbacks for when login succeeds/fails
  // final VoidCallback? onLoginSuccess;
  // final Function(String)? onTokenReceived;

  const YoutubeSignInScreen({
    super.key,
    // this.onLoginSuccess,
    // this.onTokenReceived,
  });

  @override
  State<YoutubeSignInScreen> createState() => _YoutubeSignInScreenState();
}

class _YoutubeSignInScreenState extends State<YoutubeSignInScreen> {
  GoogleSignInAccount? _currentUser;
  String _message = 'Not logged in';
  String? _accessToken; // To store the access token
  bool _isSigningIn = false; // To prevent multiple sign-in attempts
  bool _isFetchingToken = false; // To show progress while getting token

  @override
  void initState() {
    super.initState();

    // Listen for user changes (e.g., sign out from elsewhere or successful sign-in)
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      // Important: Check if the widget is still mounted before calling setState
      if (mounted) {
        _updateUser(account);
      }
    }).onError((error) {
      // Handle stream errors if necessary
      print("Error listening to user changes: $error");
      if (mounted) {
        setState(() {
          _message = "Error listening for user changes.";
          _currentUser = null;
          _accessToken = null;
        });
      }
    });

    // Try silent sign-in on screen initialization
    // Make sure this doesn't interfere with other login logic in your app
    _googleSignIn.signInSilently().then((account) {
      // No need to call _updateUser here, the listener above will handle it
    }).catchError((err) {
      print('Error during silent sign-in attempt: $err');
      // Don't necessarily show an error here, silent sign-in failing is common
      if (mounted) {
        setState(() {
          _message = 'Not logged in (silent sign-in failed or not available)';
        });
      }
    });
  }

  @override
  void dispose() {
    // It's generally good practice to cancel stream subscriptions,
    // though onCurrentUserChanged might be managed internally by the plugin.
    // If you had custom StreamSubscriptions, you'd cancel them here.
    super.dispose();
  }

  void _updateUser(GoogleSignInAccount? account) async {
    // Check mounted again just to be safe, especially with async operations
    if (!mounted) return;

    setState(() {
      _currentUser = account;
      _accessToken = null; // Reset token when user changes
      _isFetchingToken = account != null; // Start fetching if user is not null
      if (_currentUser != null) {
        _message =
            "Logged in as ${_currentUser!.displayName ?? _currentUser!.email}";
      } else {
        _message = "Not logged in";
      }
    });

    // If user is logged in, print details and get the access token
    if (_currentUser != null) {
      // --- ADDED: Print User Details to Console ---
      print("--- Google User Details ---");
      print(
          "Display Name: ${_currentUser!.displayName ?? 'Not Provided'}"); // Handle potential null display name
      print("Email: ${_currentUser!.email}");
      print("User ID: ${_currentUser!.id}"); // Added User ID as well
      print("---------------------------");
      // --- END ADDED ---

      await _getAccessToken();
    }
  }

  // Function to get the access token
  Future<void> _getAccessToken() async {
    if (_currentUser == null) return;

    // Ensure mounted check before async operation and setState
    if (!mounted) return;

    setState(() {
      _isFetchingToken = true; // Show loading indicator
    });

    try {
      final GoogleSignInAuthentication auth =
          await _currentUser!.authentication;
      if (mounted) {
        // Check again after await
        setState(() {
          _accessToken = auth.accessToken;
          _isFetchingToken = false; // Hide loading indicator
          print("Access Token: $_accessToken"); // Print for debugging
          print("ID Token: ${auth.idToken}"); // Also available
          // Optional: Call a callback if provided via widget constructor
          // widget.onTokenReceived?.call(_accessToken!);
        });
      }
    } catch (err) {
      print('Error getting authentication token: $err');
      if (mounted) {
        // Check again after await
        setState(() {
          _message = 'Error getting token: $err';
          _accessToken = null;
          _isFetchingToken = false; // Hide loading indicator
        });
      }
    }
  }

  // Sign-in function
  Future<void> _handleSignIn() async {
    if (_isSigningIn) return; // Prevent double taps

    if (!mounted) return;
    setState(() {
      _isSigningIn = true;
      _message = "Signing in..."; // Provide feedback
    });

    try {
      // Start the sign-in process
      await _googleSignIn.signIn();
      // The onCurrentUserChanged listener will handle the update upon success.
      // If signIn() returns null (user cancelled), the listener will also get null.
    } catch (error) {
      print('Error signing in: $error');
      if (mounted) {
        // Check after await
        setState(() {
          _message = 'Error signing in: $error';
          _accessToken = null; // Clear token on error
        });
      }
    } finally {
      if (mounted) {
        // Check in finally block
        setState(() {
          _isSigningIn = false; // Allow sign-in attempts again
          // If _currentUser is still null here, sign-in likely failed or was cancelled
          if (_currentUser == null && !_message.startsWith("Error")) {
            _message = "Sign in cancelled or failed.";
          }
        });
      }
    }
  }

  // Sign-out function
  Future<void> _handleSignOut() async {
    if (!mounted) return;

    setState(() {
      _message = "Signing out...";
    });

    try {
      // Disconnect removes permissions, signOut just logs out locally
      await _googleSignIn.disconnect();
      // The onCurrentUserChanged listener handles the UI update.
    } catch (error) {
      print('Error signing out: $error');
      if (mounted) {
        // Check after await
        setState(() {
          // Restore user info if disconnect fails? Or keep logged-out state?
          // Keeping logged-out state might be less confusing.
          _message = 'Error signing out: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine button states
    final bool canSignIn = !_isSigningIn && _currentUser == null;
    final bool canSignOut = _currentUser != null;
    final bool showTokenInfo = _currentUser != null;
    final bool showCopyButton = _accessToken != null;

    return Scaffold(
      // You might want to remove this AppBar if the screen is embedded
      // within another Scaffold that already has one.
      appBar: AppBar(
        title: const Text('YouTube Account Login'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center items horizontally
            children: <Widget>[
              // Display User Info or Status Message
              if (showTokenInfo) ...[
                ListTile(
                  leading: GoogleUserCircleAvatar(identity: _currentUser!),
                  title: Text(_currentUser!.displayName ?? 'No Name'),
                  subtitle: Text(_currentUser!.email),
                  contentPadding: EdgeInsets.zero, // Adjust padding if needed
                ),
                const SizedBox(height: 20),
                const Text("Access Token:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                if (_isFetchingToken)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: CircularProgressIndicator(),
                  )
                else if (_accessToken != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      _accessToken!,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 5, // Limit display lines if needed
                      scrollPhysics:
                          const ClampingScrollPhysics(), // Prevent scrolling within text box
                    ),
                  )
                else
                  const Text("Could not retrieve token.",
                      style:
                          TextStyle(color: Colors.red)), // Show if fetch failed
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Token'),
                  onPressed: showCopyButton
                      ? () {
                          Clipboard.setData(ClipboardData(text: _accessToken!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Access Token Copied!'),
                                duration: Duration(seconds: 2)),
                          );
                        }
                      : null, // Disable button if no token
                ),
              ] else ...[
                // Show Status Message when logged out or during sign-in process
                Text(_message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
              ],

              const Spacer(), // Pushes buttons towards the bottom if desired

              // Sign In / Sign Out Buttons
              if (canSignIn)
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In with Google'),
                  onPressed: _handleSignIn,
                  style: ElevatedButton.styleFrom(
                      minimumSize:
                          const Size(200, 40)), // Ensure decent button size
                )
              else if (_isSigningIn)
                const CircularProgressIndicator() // Show progress during sign-in action
              else if (canSignOut)
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out & Disconnect'),
                  onPressed: _handleSignOut,
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.redAccent, // Indicate destructive action
                      minimumSize: const Size(200, 40)),
                ),
              const SizedBox(height: 20), // Add some padding at the bottom
            ],
          ),
        ),
      ),
    );
  }
}
