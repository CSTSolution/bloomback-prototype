// The account screens (thread 0003): the sign-in buttons (Chi's screen 2 and More › Account), email one-time code,
// the Account screen (Pro, redeem code, restore, sign out, delete account) and the Pro sheet.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account/account.dart';
import '../account/api.dart';
import '../account/pro_store.dart';
import '../account/providers.dart';
import '../l10n/strings.dart';
import 'common.dart';

/// A short note; it replaces the one showing, so an old "Signed in" never holds a new message back.
void _say(BuildContext context, String text) => _sayWith(ScaffoldMessenger.maybeOf(context), text);

void _sayWith(ScaffoldMessengerState? m, String text) => m
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

String _proLine(Standing st) => !st.pro
    ? s.proRowOff
    : st.lifetime
        ? s.proLifetime
        : s.proUntil(st.proUntil ?? DateTime.now());

/// Apple (iPhone), Google and email. [name] is the first name typed on screen 2, sent with a new account.
/// Calls [onSignedIn] after a confirmed sign-in.
class SignInButtons extends StatelessWidget {
  const SignInButtons({super.key, this.name, this.onSignedIn});
  final String Function()? name;
  final VoidCallback? onSignedIn;

  @override
  Widget build(BuildContext context) {
    final account = AppScope.of(context).account;
    Future<void> run(Future<bool> Function() f) async {
      if (!account.available) {
        await showPilotSheet(context, s.accountsInApp, s.accountsInAppBody);
        return;
      }
      try {
        if (await f() && context.mounted) {
          // in onboarding the page moves on by itself; a snack bar would sit over its button
          onSignedIn == null ? _say(context, s.signedInNow) : onSignedIn!();
        }
      } on ApiProblem catch (p) {
        if (context.mounted) _say(context, p.words);
      } on ProviderTrouble catch (t) {
        if (context.mounted) _say(context, t.words);
      }
    }

    Widget button(Key key, String label, Widget icon, VoidCallback? onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(key: key, onPressed: account.busy ? null : onTap, icon: icon, label: Text(label)),
          ),
        );
    final p = account.providers;
    return Column(children: [
      if (p.appleAvailable)
        button(const Key('signInApple'), s.withApple, const Icon(Icons.apple, size: 22),
            () => run(() => account.signInWithApple(name: name?.call()))),
      button(
        const Key('signInGoogle'),
        s.withGoogle,
        const Text('G', style: TextStyle(fontWeight: FontWeight.w700, color: BBColors.data, fontSize: 16)),
        () => p.googleAvailable || !account.available
            ? run(() => account.signInWithGoogle(name: name?.call()))
            : _say(context, 'Google sign-in is not ready yet. Use email${p.appleAvailable ? ' or Apple' : ''} for now.'),
      ),
      button(const Key('signInEmail'), s.withEmail, const Icon(Icons.mail_outline, size: 20), () async {
        if (!account.available) return run(() async => false);
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => EmailSignInScreen(name: name?.call())),
        );
        if (ok == true && context.mounted) onSignedIn == null ? _say(context, s.signedInNow) : onSignedIn!();
      }),
    ]);
  }
}

/// Email, then the 6-digit code. Pops true when signed in.
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key, this.name});
  final String? name;

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _problem;

  @override
  void initState() {
    super.initState();
    // a note from the screen before (e.g. "Google sign-in is not ready") would sit over the Send button
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    });
  }

  bool get _emailOk => RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$').hasMatch(_email.text.trim());

  Future<void> _send() async {
    final account = AppScope.of(context).account;
    setState(() => _problem = null);
    try {
      await account.emailStart(_email.text);
      if (!mounted) return;
      if (_sentTo != null) _say(context, s.codeSent);
      setState(() => _sentTo = _email.text.trim());
    } on ApiProblem catch (p) {
      setState(() => _problem = p.words);
    }
  }

  Future<void> _verify() async {
    final account = AppScope.of(context).account;
    setState(() => _problem = null);
    try {
      await account.emailVerify(_sentTo!, _code.text, name: widget.name);
      if (mounted) Navigator.pop(context, true);
    } on ApiProblem catch (p) {
      setState(() => _problem = p.words);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = AppScope.of(context).account;
    final tt = Theme.of(context).textTheme;
    final codeStep = _sentTo != null;
    return BBPage(
      title: s.emailTitle,
      onBack: () => codeStep ? setState(() => _sentTo = null) : Navigator.pop(context),
      bottom: PrimaryButton(
        key: const Key('emailNext'),
        label: codeStep ? s.signInButton : s.sendCode,
        onPressed: account.busy
            ? null
            : codeStep
                ? (_code.text.trim().length == 6 ? _verify : null)
                : (_emailOk ? _send : null),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
        Text(codeStep ? s.codeTitle : s.emailTitle, style: tt.headlineSmall),
        const SizedBox(height: 6),
        Text(codeStep ? s.codeBody(_sentTo!) : s.emailBody, style: tt.bodyMedium?.copyWith(color: BBColors.muted)),
        const SizedBox(height: 18),
        if (!codeStep)
          TextField(
            key: const Key('emailField'),
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            maxLength: 254,
            decoration: InputDecoration(labelText: s.emailLabel, counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _emailOk ? _send() : null,
          )
        else ...[
          TextField(
            key: const Key('codeField'),
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            style: heading(28, weight: FontWeight.w600).copyWith(letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(labelText: s.codeLabel),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _code.text.trim().length == 6 ? _verify() : null,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: account.busy ? null : _send, child: Text(s.resendCode)),
          ),
        ],
        if (_problem != null) ...[
          const SizedBox(height: 10),
          Text(_problem!, key: const Key('emailProblem'), style: tt.bodyMedium?.copyWith(color: BBColors.accent)),
        ],
        if (account.busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}

/// More › Account.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final account = app.account;
    final tt = Theme.of(context).textTheme;
    final v = account.view;
    final st = account.standing;
    String via(String m) => switch (m) { 'apple' => s.viaApple, 'google' => s.viaGoogle, _ => s.viaEmail };

    return BBPage(
      title: s.accountTitle,
      onBack: () => Navigator.pop(context),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        if (!account.signedIn) ...[
          // Chi, thread 0004 fix 7: the same person as on Today, just not signed in
          if (app.displayName.isNotEmpty)
            BBCard(
              key: const Key('notSignedInCard'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.notSignedInName(app.displayName), style: tt.titleMedium),
                const SizedBox(height: 2),
                Text(s.notSignedInLine, style: tt.bodySmall),
              ]),
            ),
          const SizedBox(height: 8),
          Text(s.signInWith, style: tt.headlineSmall),
          const SizedBox(height: 6),
          Text(s.accountWhy, style: tt.bodyMedium?.copyWith(color: BBColors.muted)),
          const SizedBox(height: 16),
          SignInButtons(name: () => app.displayName),
        ] else ...[
          BBCard(
            key: const Key('accountCard'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CapsLabel(s.signedInAs),
              const SizedBox(height: 4),
              Text(v!.name?.isNotEmpty == true ? v.name! : (v.email ?? ''), style: tt.titleMedium),
              if (v.email != null && v.name?.isNotEmpty == true) Text(v.email!, style: tt.bodySmall),
              const SizedBox(height: 4),
              Text(v.via.map(via).join(' · '), style: tt.bodySmall),
            ]),
          ),
          BBCard(
            key: const Key('proCard'),
            color: st.pro ? BBColors.primaryLight : Colors.white,
            border: st.pro ? BBColors.primaryBorder : BBColors.line,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.local_florist, color: BBColors.accent),
                const SizedBox(width: 8),
                Expanded(child: Text(s.proName, style: tt.titleMedium)),
              ]),
              const SizedBox(height: 4),
              Text(_proLine(st), key: const Key('proStatus'), style: tt.titleSmall?.copyWith(color: st.pro ? BBColors.primary : BBColors.muted)),
              Text(st.pro ? s.askLeftPro(st.proAsksLeftToday) : s.askLeftFree(st.freeAsksLeft), style: tt.bodySmall),
              if (!st.lifetime) ...[
                const SizedBox(height: 10),
                PrimaryButton(key: const Key('openPro'), label: s.proName, onPressed: () => showProSheet(context)),
              ],
            ]),
          ),
          const SizedBox(height: 6),
          ListTile(
            key: const Key('redeemRow'),
            leading: const Icon(Icons.card_giftcard, color: BBColors.primary),
            title: Text(s.redeemCode),
            onTap: () => showRedeemSheet(context),
          ),
          ListTile(
            key: const Key('restoreRow'),
            leading: const Icon(Icons.restore, color: BBColors.primary),
            title: Text(s.restorePurchases),
            onTap: () async {
              await app.pro.start();
              await app.pro.restore();
              if (context.mounted && app.pro.note != null) _say(context, app.pro.note!);
            },
          ),
          ListTile(
            key: const Key('signOutRow'),
            leading: const Icon(Icons.logout, color: BBColors.primary),
            title: Text(s.signOut),
            subtitle: Text(s.signOutBody, style: tt.bodySmall),
            onTap: () => account.signOut(),
          ),
          ListTile(
            key: const Key('deleteAccountRow'),
            leading: const Icon(Icons.delete_outline, color: BBColors.accent),
            title: Text(s.deleteAccount),
            onTap: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text(s.deleteAccount),
                  content: Text(s.deleteAccountBody),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: Text(s.cancel)),
                    FilledButton(
                      key: const Key('deleteAccountConfirm'),
                      onPressed: () => Navigator.pop(d, true),
                      child: Text(s.deleteAccountConfirm),
                    ),
                  ],
                ),
              );
              if (yes != true || !context.mounted) return;
              // this row disappears once signed out, so keep the messenger from before
              final messenger = ScaffoldMessenger.maybeOf(context);
              try {
                await account.deleteAccount();
                _sayWith(messenger, s.accountDeleted);
              } on ApiProblem catch (p) {
                _sayWith(messenger, p.words);
              }
            },
          ),
        ],
      ]),
    );
  }
}

/// What Pro gives, the store price, buy, restore, and a way to a redeem code.
Future<void> showProSheet(BuildContext context) {
  final app = AppScope.of(context);
  app.pro.start();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => AnimatedBuilder(
      animation: Listenable.merge([app.pro, app.account]),
      builder: (c, _) {
        final tt = Theme.of(c).textTheme;
        final pro = app.pro;
        final signedIn = app.account.signedIn;
        Widget point(String t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle, color: BBColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(t)),
              ]),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.proName, style: tt.titleLarge),
              const SizedBox(height: 6),
              Text(s.proPitch),
              const SizedBox(height: 12),
              point(s.proPoint1),
              point(s.proPoint2),
              point(s.proPoint3),
              const SizedBox(height: 4),
              Text(s.proFreeNote, style: tt.bodySmall),
              const SizedBox(height: 14),
              if (!signedIn) ...[
                Text(s.signInForPro, style: tt.bodyMedium?.copyWith(color: BBColors.accent)),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: s.signInWith,
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));
                  },
                ),
              ] else if (pro.state == ProState.owned || (app.account.standing.lifetime)) ...[
                Text(s.proLifetime, style: tt.titleSmall?.copyWith(color: BBColors.primary)),
              ] else ...[
                PrimaryButton(
                  key: const Key('buyPro'),
                  label: pro.price == null ? s.proBuyNoPrice : s.proBuy(pro.price!),
                  onPressed: pro.state == ProState.forSale ? pro.buy : null,
                ),
                if (pro.state == ProState.unavailable) ...[
                  const SizedBox(height: 6),
                  Text(s.proUnavailable, style: tt.bodySmall),
                ],
                if (pro.state == ProState.working)
                  const Padding(padding: EdgeInsets.only(top: 10), child: Center(child: CircularProgressIndicator())),
                Wrap(alignment: WrapAlignment.spaceBetween, children: [
                  TextButton(onPressed: pro.restore, child: Text(s.restorePurchases)),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(c);
                      showRedeemSheet(context);
                    },
                    child: Text(s.redeemCode),
                  ),
                ]),
              ],
              if (pro.note != null) ...[
                const SizedBox(height: 6),
                Text(pro.note!, style: tt.bodySmall),
              ],
            ]),
          ),
        );
      },
    ),
  );
}

Future<void> showRedeemSheet(BuildContext context) {
  final account = AppScope.of(context).account;
  final c = TextEditingController();
  String? problem;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.redeemCode, style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (!account.signedIn)
            Text(s.signInForPro)
          else ...[
            TextField(
              key: const Key('redeemField'),
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              maxLength: 20,
              decoration: InputDecoration(labelText: s.redeemLabel, counterText: ''),
            ),
            if (problem != null) ...[
              const SizedBox(height: 6),
              Text(problem!, style: const TextStyle(color: BBColors.accent)),
            ],
            const SizedBox(height: 12),
            PrimaryButton(
              key: const Key('redeemSend'),
              label: s.redeem,
              onPressed: () async {
                try {
                  final days = await account.redeem(c.text);
                  if (!sheet.mounted) return;
                  Navigator.pop(sheet);
                  _say(context, s.redeemDone(days));
                } on ApiProblem catch (p) {
                  setSheet(() => problem = p.words);
                }
              },
            ),
          ],
        ]),
      ),
    ),
  );
}
