# LUCARO GARAGEM — primeira versão

Site responsivo da estética automotiva, com área pública para clientes e painel do proprietário.

## O que já está preparado
- Página inicial com identidade azul-marinho / azul-claro e espaços para a logo oficial.
- Catálogo inicial de serviços (nomes editáveis; preços e duração vazios).
- Galeria visual de referência para polimento, vitrificação, lavagem e detalhamento.
- Formulário de solicitação de agendamento.
- Estrutura Supabase para bloquear duplicidade de data/horário (um horário por reserva) e painel de gestão.
- Área do proprietário com login, agenda, alteração de preços/duração, stories, aviso geral, localização e história.
- Chat cliente-proprietário e publicações de foto/vídeo (dependem da configuração do Supabase).

## Rodar localmente
1. Instale Node.js LTS.
2. Na pasta do projeto, execute `npm install`.
3. Copie `.env.example` para `.env` e preencha as credenciais do projeto Supabase.
4. Execute `npm run dev`.

## Configurar Supabase (necessário para dados compartilhados)
1. Crie um projeto no Supabase.
2. Em SQL Editor, execute `supabase/schema.sql`.
3. Em Authentication, habilite Email/Password e crie o usuário proprietário.
4. Em Storage, crie um bucket público chamado `lucaro-stories`.
5. Em Database > Replication, habilite Realtime para `bookings` e `chat_messages`.
6. Copie Project URL e anon/public key para `.env`.

## Publicar na Vercel
1. Envie a pasta para um repositório GitHub.
2. Importe o repositório na Vercel.
3. Configure `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` nas Environment Variables.
4. Deploy. A Vercel fornecerá o endereço público; depois, gere o QR Code com esse link.

## Antes de abrir ao público
- Substituir o monograma provisório pela logo oficial da LUCARO GARAGEM.
- Conferir e substituir fotos ilustrativas por imagens próprias/licenciadas.
- Configurar endereço completo, WhatsApp, preços, tempos e horário de funcionamento.
- Revisar regras de segurança do Supabase. Esta versão é um ponto de partida técnico; o chat público e a administração precisam de políticas mais restritas e teste de segurança antes de receber clientes reais.
- Adicionar política de privacidade e definir retenção dos dados de contato conforme a LGPD.

## Limite atual do agendamento
O banco impede duas reservas no mesmo dia e horário exato. Para controlar duração variável (ex.: polimento ocupa 4 horas e lavagem ocupa 1 hora), será necessário configurar expediente, intervalos, duração e regras de sobreposição no próximo ajuste. O painel já deixa o campo de duração preparado.

### Segurança e duração dos agendamentos
- Habilite Anonymous Sign-Ins em Authentication para o chat dos clientes.
- Depois de criar o usuário proprietário em Authentication, atribua `app_metadata.role = admin` a esse usuário (via fluxo administrativo seguro do Supabase; não use `user_metadata`). As políticas do banco verificam essa função.
- O SQL impede sobreposição de horários usando a duração cadastrada. Enquanto a duração estiver vazia, a reserva ocupa o restante do dia como proteção contra conflitos. Cadastre durações reais antes de abrir a agenda ao público.
