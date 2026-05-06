## Request spec authentication policy

Request specs are divided by responsibility.

- `authentication_spec` はトークン未指定・不正なトークン・有効なトークンなど、認証そのものの挙動を確認する
- books_specでは認証済みユーザーがいる前提で、Book Apiのレスポンス構造や所有権スコープを確認する
- 通常の機能ごとのrequest specでは、ログイン処理を毎回検証するのではなく、各specの責務に集中するために認証をstubする
- 実際の認証フローを確認する必要があるspecでは、autj: :realを使って認証stubを回避する
- book indexの所有権specでは、response bodyに認証済みユーザー本人のBookだけが含まれ、他ユーザーのBookが含まれないことを確認する。