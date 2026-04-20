# notes#destroy 認可メモ

## 現在の問題
- `notes#destroy` で `Note.find(params[:id])` を使っている
- このままだと、current_user の所有範囲外の note に触れられる可能性がある

## 認可の方向性
- destroy の対象は、current_user が所有している note の中の1件にする
- 所有関係は `user -> books -> notes` で辿る
- グローバルな `Note` 全体から取得しない

## 期待する動作
- 自分の note は削除できる
- 他人の note は削除できない
- current_user の所有範囲で見つからなければ失敗として扱う

## 次にやること
- 今の Rails の関連の中で、所有者スコープ付きの note 集合をどう表現するか決める
- 実装後、user A / user B で確認する