# stock 📦

> Aplicativo móvel minimalista de controle de estoque sincronizado em tempo real entre usuários autorizados.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Material 3](https://img.shields.io/badge/Material_3-7C3AED?style=for-the-badge&logo=materialdesign&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

---

## ✨ Funcionalidades

- **🔒 Acesso Fechado & Seguro**: Sem telas de cadastro público. Apenas usuários criados previamente pelo administrador têm acesso ao sistema.
- **⚡ Sincronização em Tempo Real (Realtime)**: Alterações no estoque feitas em um celular refletem instantaneamente em todos os outros dispositivos conectados.
- **➕ / ➖ Controle Rápido de Entradas e Saídas**:
  - Toque rápido em `+` ou `-` para movimentar 1 unidade imediatamente.
  - Toque longo ou seleção para informar quantidades personalizadas.
  - Validação estrita para evitar que o estoque fique negativo.
- **✏️ Edição e Exclusão**: Modificação rápida de nome, categoria e quantidade em estoque, ou exclusão com diálogo de confirmação.
- **🏷️ Organização por Categorias**:
  - Atribuição de categoria no cadastro ou edição.
  - Filtro horizontal interativo para visualizar produtos por categoria ou catálogo completo.
- **🔄 Ordenação Inteligente**:
  - Mais recentes / Mais antigos (data de modificação).
  - Ordem alfabética (A-Z e Z-A).
  - Quantidade em estoque (Maior ou Menor).
- **📋 Histórico de Movimentações**: Registro auditável em tempo real de quem fez a movimentação (e-mail), qual produto, tipo (Entrada/Saída), quantidade e data/hora.
- **📁 Identidade Visual**: Ícone moderno no estilo *file explorer folder* e visual limpo seguindo as diretrizes do Material 3.

---

## 🛠️ Stack Tecnológica (100% Gratuita)

- **Frontend**: Flutter (Dart) com Material 3.
- **Backend / Banco de Dados**: Supabase (PostgreSQL relacional com Realtime nativo via WebSockets).
- **Autenticação**: Supabase Auth (E-mail e Senha).

---

## 📂 Estrutura do Projeto

```
lib/
├── core/
│   ├── constants.dart                  # Configurações e credenciais do Supabase
│   ├── supabase_client.dart            # Instância singleton do cliente Supabase
│   └── theme.dart                      # Tema minimalista Material 3
├── models/
│   ├── movement.dart                   # Modelo de dados de movimentações
│   └── product.dart                    # Modelo de dados de produtos
├── screens/
│   ├── auth/
│   │   └── login_screen.dart           # Tela de autenticação restrita
│   ├── inventory/
│   │   ├── inventory_screen.dart       # Tela principal (busca, categorias, ordenação)
│   │   └── widgets/
│   │       ├── add_product_modal.dart  # Modal para cadastrar novo produto
│   │       ├── edit_product_modal.dart # Modal para editar produto existente
│   │       ├── movement_history_tab.dart # Aba do histórico de movimentações
│   │       ├── product_card.dart       # Card de produto com ações rápidas
│   │       └── stock_action_dialog.dart# Diálogo de quantidade para entrada/saída
│   └── splash_screen.dart              # Redirecionamento baseado na sessão ativa
└── main.dart                           # Ponto de entrada da aplicação
```

---

## 🗄️ Esquema do Banco de Dados (Supabase SQL)

Para reproduzir o banco de dados no Supabase, basta executar o seguinte script no **SQL Editor**:

```sql
-- 1. Tabela de Produtos
create table if not exists products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  sku_or_category text,
  quantity integer not null default 0 check (quantity >= 0),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Tabela de Histórico de Movimentações
create table if not exists stock_movements (
  id uuid default gen_random_uuid() primary key,
  product_id uuid references products(id) on delete cascade not null,
  product_name text not null,
  type text not null check (type in ('ENTRY', 'EXIT')),
  quantity integer not null check (quantity > 0),
  user_email text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Habilitar Sincronização em Tempo Real (Realtime)
alter publication supabase_realtime add table products;
alter publication supabase_realtime add table stock_movements;

-- 4. Função Atômica para Ajuste Concorrente de Estoque
create or replace function update_stock(
  p_product_id uuid,
  p_product_name text,
  p_type text,
  p_quantity integer,
  p_user_email text
) returns void as $$
declare
  v_current_quantity integer;
begin
  select quantity into v_current_quantity from products where id = p_product_id for update;
  
  if p_type = 'ENTRY' then
    update products 
    set quantity = quantity + p_quantity, updated_at = now() 
    where id = p_product_id;
  elsif p_type = 'EXIT' then
    if v_current_quantity < p_quantity then
      raise exception 'Estoque insuficiente para esta saída';
    end if;
    update products 
    set quantity = quantity - p_quantity, updated_at = now() 
    where id = p_product_id;
  end if;

  insert into stock_movements (product_id, product_name, type, quantity, user_email)
  values (p_product_id, p_product_name, p_type, p_quantity, p_user_email);
end;
$$ language plpgsql security definer;

-- 5. Segurança por Nível de Linha (RLS)
alter table products enable row level security;
alter table stock_movements enable row level security;

create policy "Autenticados leem produtos" on products for select to authenticated using (true);
create policy "Autenticados criam produtos" on products for insert to authenticated with check (true);
create policy "Autenticados editam produtos" on products for update to authenticated using (true);
create policy "Autenticados deletam produtos" on products for delete to authenticated using (true);

create policy "Autenticados leem movimentacoes" on stock_movements for select to authenticated using (true);
create policy "Autenticados gravam movimentacoes" on stock_movements for insert to authenticated with check (true);
```

---

## 🚀 Como Executar o Projeto

### Pré-requisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13+)
- Dispositivo Android com depuração USB ou Emulador Android

### 1. Clonar o repositório
```bash
git clone https://github.com/tomi-pereyra/stock.git
cd stock
```

### 2. Instalar dependências
```bash
flutter pub get
```

### 3. Configurar Credenciais
No arquivo `lib/core/constants.dart`, insira sua URL e Chave Pública do Supabase:
```dart
class AppConstants {
  static const String supabaseUrl = 'https://SEU-PROJETO.supabase.co';
  static const String supabasePublishableKey = 'SUA-CHAVE-PUBLICA';
}
```

### 4. Executar em modo Debug
```bash
flutter run
```

### 5. Compilar APK de Release
```bash
flutter build apk --release
```
O arquivo final estará localizado em `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 Licença
Distribuído sob a licença MIT. Consulte `LICENSE` para obter mais detalhes.
