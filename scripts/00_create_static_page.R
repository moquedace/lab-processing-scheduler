rm(list = ls())
gc()

project_root <- getwd()

if (!grepl("lab-processing-scheduler$", project_root)) {
  stop(
    "The working directory does not appear to be the project root. ",
    "In RStudio, go to: Session > Set Working Directory > To Project Directory"
  )
}

docs_dir <- file.path(project_root, "docs")
css_dir <- file.path(docs_dir, "assets", "css")
img_dir <- file.path(docs_dir, "assets", "img")

dir.create(css_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(img_dir, recursive = TRUE, showWarnings = FALSE)

index_file <- file.path(docs_dir, "index.html")
css_file <- file.path(css_dir, "main.css")

expected_logos <- file.path(
  img_dir,
  c(
    "logo_geocis.png",
    "logo_solos.png",
    "logo_esalq.png",
    "logo_usp.png",
    "logo_fapesp.png"
  )
)

missing_logos <- expected_logos[!file.exists(expected_logos)]

if (length(missing_logos) > 0) {
  message("Atenção: as seguintes logos ainda não foram encontradas:")
  message(paste(basename(missing_logos), collapse = "\n"))
  message("Salve esses arquivos em: ", img_dir)
}

html_content <- r"(
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />

  <title>Reserva dos Computadores de Processamento</title>

  <link rel="stylesheet" href="assets/css/main.css" />

  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link
    href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap"
    rel="stylesheet"
  />
</head>

<body>
  <main class="page-shell">
    <header class="institutional-header">
      <div class="institutional-main">
        <img
          src="assets/img/logo_geocis.png"
          alt="GeoCIS"
          class="logo-geocis"
        />

        <div class="institutional-text">
          <span>Grupo de Geotecnologias em Ciência do Solo</span>
          <strong>Departamento de Ciência do Solo | ESALQ | USP</strong>
        </div>
      </div>

      <div class="institutional-logo-row">
        <img
          src="assets/img/logo_solos.png"
          alt="Departamento de Ciência do Solo"
          class="logo-institution logo-solos"
        />

        <img
          src="assets/img/logo_esalq.png"
          alt="ESALQ"
          class="logo-institution logo-esalq"
        />

        <img
          src="assets/img/logo_usp.png"
          alt="USP"
          class="logo-institution logo-usp"
        />

        <div class="support-logo-box">
          <span>Apoio</span>
          <img
            src="assets/img/logo_fapesp.png"
            alt="FAPESP"
            class="logo-institution logo-fapesp"
          />
        </div>
      </div>
    </header>

    <section class="hero-section">
      <div class="hero-content">
        <div class="hero-badge">
          Fila de Processamento do Laboratório
        </div>

        <h1>Reserva dos Computadores de Processamento</h1>

        <p class="hero-text">
          Plataforma interna para consulta, solicitação e gestão do uso
          compartilhado das estações Super 1 e Super 2, vinculadas à
          infraestrutura computacional do Grupo de Geotecnologias em Ciência
          do Solo.
        </p>

        <div class="hero-actions">
          <a href="#status-section" class="button button-primary">
            Ver disponibilidade
          </a>

          <a href="#booking-section" class="button button-secondary">
            Solicitar reserva
          </a>
        </div>
      </div>

      <aside class="hero-summary-card">
        <span class="summary-label">Status geral</span>

        <div class="summary-main">2</div>

        <p>
          estações disponíveis para processamento científico de alta demanda.
        </p>

        <div class="summary-list">
          <div>
            <span>Super 1</span>
            <strong>Disponível</strong>
          </div>

          <div>
            <span>Super 2</span>
            <strong>Em uso</strong>
          </div>
        </div>
      </aside>
    </section>

    <section class="content-section">
      <div class="about-lab-card">
        <div>
          <span class="section-kicker">Sobre a infraestrutura</span>
          <h2>GeoCIS | Geotecnologias em Ciência do Solo</h2>
        </div>

        <p>
          O sistema apoia a organização do uso da infraestrutura computacional
          compartilhada do laboratório, promovendo transparência, priorização
          adequada e melhor aproveitamento das estações de alto desempenho.
        </p>

        <div class="about-meta-grid">
          <div>
            <span>Laboratório</span>
            <strong>Geotecnologias em Ciência do Solo</strong>
          </div>

          <div>
            <span>Vínculo institucional</span>
            <strong>Departamento de Ciência do Solo, ESALQ, USP</strong>
          </div>

          <div>
            <span>Coordenação</span>
            <strong>Prof. José Alexandre Melo Demattê</strong>
          </div>

          <div>
            <span>Finalidade</span>
            <strong>Gestão do uso compartilhado das estações Super 1 e Super 2</strong>
          </div>
        </div>
      </div>
    </section>

    <section id="status-section" class="content-section">
      <div class="section-header">
        <div>
          <span class="section-kicker">Disponibilidade</span>
          <h2>Status atual</h2>
        </div>

        <p>
          Painel público para consulta rápida da situação dos computadores.
        </p>
      </div>

      <div class="status-grid">
        <article class="computer-card available-card">
          <div class="computer-card-header">
            <div>
              <h3>Super 1</h3>
              <span>Processamento científico geral</span>
            </div>

            <div class="status-pill status-available">
              Disponível
            </div>
          </div>

          <p>
            Indicado para rotinas em R, Python via VS Code, processamento
            espacial, modelagens intermediárias, tarefas com GPU de demanda
            moderada e processamentos longos.
          </p>

          <div class="computer-info-grid">
            <div>
              <span>Usuário atual</span>
              <strong>Nenhum</strong>
            </div>

            <div>
              <span>Fim previsto</span>
              <strong>Livre agora</strong>
            </div>

            <div>
              <span>Processamento</span>
              <strong>Nenhum em execução</strong>
            </div>

            <div>
              <span>Próxima reserva</span>
              <strong>Hoje, 18:00</strong>
            </div>
          </div>
        </article>

        <article class="computer-card busy-card">
          <div class="computer-card-header">
            <div>
              <h3>Super 2</h3>
              <span>Processamento intensivo e paralelo</span>
            </div>

            <div class="status-pill status-busy">
              Em uso
            </div>
          </div>

          <p>
            Prioritário para processamentos críticos, rotinas intensivas em R
            ou Python, tarefas com alta demanda de memória, modelagens paralelas,
            grandes mosaicos raster e predições espaciais em larga escala.
          </p>

          <div class="computer-info-grid">
            <div>
              <span>Usuário atual</span>
              <strong>Ana Silva</strong>
            </div>

            <div>
              <span>Fim previsto</span>
              <strong>Hoje, 17:30</strong>
            </div>

            <div>
              <span>Processamento</span>
              <strong>Modelagem raster</strong>
            </div>

            <div>
              <span>Próxima reserva</span>
              <strong>Amanhã, 08:00</strong>
            </div>
          </div>
        </article>
      </div>
    </section>

    <section class="content-section">
      <div class="section-header">
        <div>
          <span class="section-kicker">Infraestrutura</span>
          <h2>Capacidade técnica</h2>
        </div>

        <p>
          Especificações principais para orientar a escolha do computador mais adequado.
        </p>
      </div>

      <div class="spec-grid">
        <article class="spec-card">
          <div class="spec-card-top">
            <div>
              <span class="spec-label">Super 1</span>
              <h3>Estação robusta para processamento científico geral</h3>
            </div>

            <div class="spec-chip">R, Python e GPU</div>
          </div>

          <div class="spec-metrics">
            <div>
              <span>Processador</span>
              <strong>2 x Intel Xeon Gold 5120T</strong>
            </div>

            <div>
              <span>Núcleos e threads</span>
              <strong>28 núcleos | 56 threads</strong>
            </div>

            <div>
              <span>Memória RAM</span>
              <strong>128 GB</strong>
            </div>

            <div>
              <span>GPU</span>
              <strong>NVIDIA Quadro RTX 4000, 8 GB</strong>
            </div>
          </div>

          <div class="best-use">
            <span>Melhor uso</span>
            <p>
              Rotinas em R, scripts em Python via VS Code, processamento
              espacial, modelagens intermediárias, tarefas com GPU de demanda
              moderada e processamentos longos que não exigem a capacidade
              máxima do Super 2.
            </p>
          </div>
        </article>

        <article class="spec-card featured">
          <div class="spec-card-top">
            <div>
              <span class="spec-label">Super 2</span>
              <h3>Estação principal para processamento intensivo</h3>
            </div>

            <div class="spec-chip featured-chip">Prioritário</div>
          </div>

          <div class="spec-metrics">
            <div>
              <span>Processador</span>
              <strong>AMD Ryzen Threadripper PRO 7985WX</strong>
            </div>

            <div>
              <span>Núcleos e threads</span>
              <strong>64 núcleos | 128 threads</strong>
            </div>

            <div>
              <span>Memória RAM</span>
              <strong>512 GB</strong>
            </div>

            <div>
              <span>GPU</span>
              <strong>NVIDIA RTX 4000 Ada Generation</strong>
            </div>
          </div>

          <div class="best-use">
            <span>Melhor uso</span>
            <p>
              Processamento paralelo intensivo, grandes mosaicos raster,
              modelagens pesadas, predições espaciais em larga escala,
              rotinas em R ou Python com alto consumo de memória e tarefas
              que exigem muitos núcleos de CPU.
            </p>
          </div>
        </article>
      </div>

      <div class="recommendation-card">
        <div>
          <span class="section-kicker recommendation-kicker">Orientação rápida</span>
          <h3>Qual computador devo solicitar?</h3>
        </div>

        <p>
          Solicite o Super 2 quando o processamento exigir muita memória RAM,
          elevado paralelismo, grande volume raster ou execução intensiva em CPU.
          O Super 1 atende bem rotinas em R ou Python, modelagens intermediárias,
          processamentos espaciais e tarefas com GPU de demanda moderada.
        </p>
      </div>
    </section>

    <section class="content-section">
      <div class="section-header">
        <div>
          <span class="section-kicker">Agenda</span>
          <h2>Próximas reservas</h2>
        </div>

        <p>
          Visualização pública das reservas aprovadas e pendentes.
        </p>
      </div>

      <div class="table-card">
        <table>
          <thead>
            <tr>
              <th>Computador</th>
              <th>Usuário</th>
              <th>Início</th>
              <th>Fim previsto</th>
              <th>Tipo</th>
              <th>Status</th>
            </tr>
          </thead>

          <tbody>
            <tr>
              <td>Super 1</td>
              <td>João Pereira</td>
              <td>Hoje, 18:00</td>
              <td>Amanhã, 08:00</td>
              <td>Espectroscopia</td>
              <td>
                <span class="table-status approved">Aprovada</span>
              </td>
            </tr>

            <tr>
              <td>Super 2</td>
              <td>Marina Costa</td>
              <td>Amanhã, 08:00</td>
              <td>Amanhã, 18:00</td>
              <td>Random forest</td>
              <td>
                <span class="table-status approved">Aprovada</span>
              </td>
            </tr>

            <tr>
              <td>Super 2</td>
              <td>Pedro Almeida</td>
              <td>Amanhã, 19:00</td>
              <td>Depois de amanhã, 08:00</td>
              <td>Mosaico raster</td>
              <td>
                <span class="table-status pending">Pendente</span>
              </td>
            </tr>

            <tr>
              <td>Qualquer um</td>
              <td>Carla Mendes</td>
              <td>14/05, 09:00</td>
              <td>14/05, 17:00</td>
              <td>Modelagem estatística</td>
              <td>
                <span class="table-status pending">Pendente</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section id="booking-section" class="content-section booking-layout">
      <div class="booking-card">
        <div class="section-header compact">
          <div>
            <span class="section-kicker">Solicitação</span>
            <h2>Solicitar reserva</h2>
          </div>
        </div>

        <p class="booking-text">
          Nesta área será incorporado o formulário dinâmico do Shiny.
          Por enquanto, este bloco funciona como marcador visual do sistema.
        </p>

        <div class="iframe-placeholder">
          <div>
            <span>Shiny App</span>
            <strong>Formulário de reserva será incorporado aqui</strong>

            <p>
              Campos futuros: nome, e-mail, categoria, ambiente principal
              de processamento, computador desejado, data, horário, duração,
              tipo de demanda, uso de GPU, necessidade obrigatória do Super 2
              e justificativa.
            </p>
          </div>
        </div>
      </div>

      <aside class="rules-card">
        <span class="section-kicker">Uso responsável</span>

        <h2>Regras gerais</h2>

        <ul>
          <li>Reservas comuns podem ter até 24 horas.</li>
          <li>Reservas acima de 24 horas exigem justificativa.</li>
          <li>O Super 2 deve ser priorizado para processamentos críticos.</li>
          <li>Usuários com prazos formais podem ter prioridade.</li>
          <li>Ao finalizar antes do horário, libere o computador no sistema.</li>
          <li>Reservas de iniciação científica são excepcionais.</li>
        </ul>
      </aside>
    </section>

    <section class="content-section">
      <div class="admin-card">
        <div>
          <span class="section-kicker admin-kicker">Gestão</span>

          <h2>Acesso administrativo</h2>

          <p>
            Área reservada para aprovação de solicitações, edição de horários,
            cancelamentos, registro de uso e exportação do histórico.
          </p>
        </div>

        <a href="#" class="button button-dark">
          Entrar como administrador
        </a>
      </div>
    </section>

    <footer class="footer">
      <div class="footer-main">
        <img
          src="assets/img/logo_geocis.png"
          alt="GeoCIS"
          class="footer-logo"
        />

        <div>
          <p>Grupo de Geotecnologias em Ciência do Solo</p>
          <span>
            Departamento de Ciência do Solo | Escola Superior de Agricultura Luiz de Queiroz | Universidade de São Paulo
          </span>
        </div>
      </div>

      <div class="footer-support">
        <span>Apoio</span>
        <img
          src="assets/img/logo_fapesp.png"
          alt="FAPESP"
          class="footer-fapesp"
        />
      </div>
    </footer>
  </main>
</body>
</html>
)"

css_content <- r"(
:root {
  --background: #f4f7fb;
  --surface: #ffffff;
  --surface-soft: #f8fafc;
  --text-main: #101828;
  --text-muted: #667085;
  --text-light: #ffffff;
  --primary: #1f4f7a;
  --primary-dark: #123552;
  --primary-soft: #e8f1fb;
  --green: #0f8a5f;
  --green-soft: #e8f7ef;
  --orange: #b85c00;
  --orange-soft: #fff2df;
  --border: #e5e7eb;
  --shadow: 0 20px 55px rgba(15, 23, 42, 0.08);
  --radius-large: 30px;
  --radius-medium: 22px;
  --radius-small: 14px;
}

* {
  box-sizing: border-box;
}

html {
  scroll-behavior: smooth;
}

body {
  margin: 0;
  font-family: Inter, Arial, Helvetica, sans-serif;
  color: var(--text-main);
  background: var(--background);
}

a {
  color: inherit;
  text-decoration: none;
}

.page-shell {
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, rgba(31, 79, 122, 0.18), transparent 34rem),
    linear-gradient(180deg, #eef5fb 0%, #f7f9fc 42%, #ffffff 100%);
}

.institutional-header {
  display: flex;
  justify-content: space-between;
  gap: 28px;
  align-items: center;
  padding: 24px 7vw 10px;
}

.institutional-main {
  display: flex;
  gap: 18px;
  align-items: center;
  min-width: 320px;
}

.logo-geocis {
  width: 88px;
  height: 88px;
  object-fit: contain;
}

.institutional-text {
  display: grid;
  gap: 4px;
}

.institutional-text span {
  color: var(--text-muted);
  font-size: 0.92rem;
  font-weight: 700;
}

.institutional-text strong {
  color: #111827;
  font-size: 1rem;
  line-height: 1.35;
}

.institutional-logo-row {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 18px;
  align-items: center;
}

.logo-institution {
  display: block;
  max-width: 100%;
  object-fit: contain;
  filter: saturate(0.95);
}

.logo-solos {
  height: 54px;
}

.logo-esalq {
  height: 48px;
  max-width: 260px;
}

.logo-usp {
  height: 44px;
  max-width: 150px;
}

.logo-fapesp {
  height: 38px;
  max-width: 170px;
}

.support-logo-box {
  display: flex;
  gap: 10px;
  align-items: center;
  padding-left: 18px;
  border-left: 1px solid rgba(102, 112, 133, 0.24);
}

.support-logo-box span {
  color: var(--text-muted);
  font-size: 0.76rem;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.hero-section {
  display: grid;
  grid-template-columns: minmax(0, 1.5fr) minmax(320px, 0.75fr);
  gap: 28px;
  align-items: stretch;
  padding: 28px 7vw 28px;
}

.hero-content,
.hero-summary-card,
.computer-card,
.table-card,
.booking-card,
.rules-card,
.admin-card,
.spec-card,
.recommendation-card,
.about-lab-card {
  border: 1px solid rgba(255, 255, 255, 0.78);
  box-shadow: var(--shadow);
}

.hero-content {
  padding: 38px;
  border-radius: var(--radius-large);
  background: rgba(255, 255, 255, 0.78);
  backdrop-filter: blur(16px);
}

.hero-badge,
.section-kicker {
  display: inline-flex;
  width: fit-content;
  align-items: center;
  gap: 8px;
  margin-bottom: 18px;
  padding: 8px 14px;
  border-radius: 999px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 0.84rem;
  font-weight: 800;
  letter-spacing: 0.02em;
}

.hero-content h1 {
  max-width: 900px;
  margin: 0 0 20px;
  color: #0f172a;
  font-size: clamp(2.4rem, 5.4vw, 4.8rem);
  line-height: 0.98;
  letter-spacing: -0.06em;
}

.hero-text {
  max-width: 820px;
  margin: 0 0 28px;
  color: #475467;
  font-size: 1.08rem;
  line-height: 1.72;
}

.hero-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 46px;
  padding: 12px 19px;
  border-radius: 999px;
  font-weight: 800;
  transition: all 0.2s ease;
}

.button-primary {
  color: var(--text-light);
  background: var(--primary);
  box-shadow: 0 12px 24px rgba(31, 79, 122, 0.22);
}

.button-primary:hover {
  background: var(--primary-dark);
  transform: translateY(-1px);
}

.button-secondary {
  color: var(--primary);
  background: var(--primary-soft);
}

.button-secondary:hover {
  background: #d9eafa;
  transform: translateY(-1px);
}

.button-dark {
  color: var(--text-light);
  background: #111827;
}

.button-dark:hover {
  background: #020617;
  transform: translateY(-1px);
}

.hero-summary-card {
  position: relative;
  overflow: hidden;
  padding: 30px;
  border-radius: var(--radius-large);
  color: var(--text-light);
  background: #0f172a;
}

.hero-summary-card::after {
  position: absolute;
  top: -90px;
  right: -80px;
  width: 230px;
  height: 230px;
  content: "";
  border-radius: 999px;
  background: rgba(59, 130, 246, 0.24);
}

.summary-label {
  display: block;
  margin-bottom: 18px;
  color: #bfdbfe;
  font-size: 0.9rem;
  font-weight: 800;
}

.summary-main {
  margin-bottom: 8px;
  font-size: 4rem;
  font-weight: 900;
  line-height: 1;
}

.hero-summary-card p {
  max-width: 330px;
  margin: 0 0 28px;
  color: #cbd5e1;
  line-height: 1.65;
}

.summary-list {
  display: grid;
  gap: 13px;
}

.summary-list div {
  display: flex;
  justify-content: space-between;
  gap: 20px;
  padding-top: 13px;
  border-top: 1px solid rgba(255, 255, 255, 0.12);
}

.summary-list span {
  color: #cbd5e1;
}

.summary-list strong {
  color: #ffffff;
}

.content-section {
  padding: 22px 7vw;
}

.about-lab-card {
  padding: 28px;
  border-radius: var(--radius-large);
  background:
    radial-gradient(circle at top right, rgba(31, 79, 122, 0.07), transparent 18rem),
    rgba(255, 255, 255, 0.88);
}

.about-lab-card h2 {
  margin: 0 0 14px;
  font-size: 1.7rem;
  letter-spacing: -0.035em;
}

.about-lab-card p {
  max-width: 980px;
  margin: 0 0 22px;
  color: #475467;
  line-height: 1.7;
}

.about-meta-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.about-meta-grid div {
  padding: 16px;
  border: 1px solid var(--border);
  border-radius: var(--radius-small);
  background: #ffffff;
}

.about-meta-grid span {
  display: block;
  margin-bottom: 7px;
  color: var(--text-muted);
  font-size: 0.8rem;
  font-weight: 800;
}

.about-meta-grid strong {
  color: #111827;
  font-size: 0.92rem;
  line-height: 1.35;
}

.section-header {
  display: flex;
  justify-content: space-between;
  gap: 22px;
  align-items: end;
  margin-bottom: 18px;
}

.section-header.compact {
  display: block;
}

.section-header h2 {
  margin: 0;
  color: #101828;
  font-size: 1.7rem;
  letter-spacing: -0.035em;
}

.section-header p {
  max-width: 560px;
  margin: 0;
  color: var(--text-muted);
  line-height: 1.55;
  text-align: right;
}

.status-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 22px;
}

.computer-card {
  padding: 28px;
  border-radius: var(--radius-large);
  background: var(--surface);
}

.available-card {
  border-color: rgba(15, 138, 95, 0.18);
}

.busy-card {
  border-color: rgba(184, 92, 0, 0.2);
}

.computer-card-header {
  display: flex;
  justify-content: space-between;
  gap: 18px;
  align-items: start;
  margin-bottom: 18px;
}

.computer-card h3 {
  margin: 0 0 5px;
  font-size: 1.65rem;
  letter-spacing: -0.04em;
}

.computer-card-header span {
  color: var(--text-muted);
  font-weight: 600;
}

.status-pill,
.table-status,
.spec-chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: fit-content;
  padding: 8px 12px;
  border-radius: 999px;
  font-size: 0.82rem;
  font-weight: 900;
  white-space: nowrap;
}

.status-available {
  color: var(--green);
  background: var(--green-soft);
}

.status-busy {
  color: var(--orange);
  background: var(--orange-soft);
}

.computer-card p {
  margin: 0 0 24px;
  color: var(--text-muted);
  line-height: 1.68;
}

.computer-info-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.computer-info-grid div {
  padding: 16px;
  border: 1px solid var(--border);
  border-radius: var(--radius-small);
  background: var(--surface-soft);
}

.computer-info-grid span {
  display: block;
  margin-bottom: 6px;
  color: var(--text-muted);
  font-size: 0.82rem;
  font-weight: 700;
}

.computer-info-grid strong {
  color: #111827;
  font-size: 0.96rem;
}

.spec-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 22px;
}

.spec-card {
  padding: 28px;
  border-radius: var(--radius-large);
  background: var(--surface);
}

.spec-card.featured {
  border-color: rgba(31, 79, 122, 0.24);
  background:
    radial-gradient(circle at top right, rgba(31, 79, 122, 0.08), transparent 18rem),
    var(--surface);
}

.spec-card-top {
  display: flex;
  justify-content: space-between;
  gap: 18px;
  align-items: start;
  margin-bottom: 22px;
}

.spec-label {
  display: block;
  margin-bottom: 8px;
  color: var(--primary);
  font-size: 0.86rem;
  font-weight: 900;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.spec-card h3 {
  margin: 0;
  font-size: 1.45rem;
  line-height: 1.2;
  letter-spacing: -0.035em;
}

.spec-chip {
  color: var(--primary);
  background: var(--primary-soft);
}

.featured-chip {
  color: #ffffff;
  background: var(--primary);
}

.spec-metrics {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
  margin-bottom: 22px;
}

.spec-metrics div {
  padding: 16px;
  border: 1px solid var(--border);
  border-radius: var(--radius-small);
  background: var(--surface-soft);
}

.spec-metrics span,
.best-use span {
  display: block;
  margin-bottom: 7px;
  color: var(--text-muted);
  font-size: 0.82rem;
  font-weight: 800;
}

.spec-metrics strong {
  color: #111827;
  font-size: 0.94rem;
  line-height: 1.4;
}

.best-use {
  padding: 18px;
  border-radius: var(--radius-medium);
  background: #f8fafc;
}

.best-use p {
  margin: 0;
  color: #475467;
  line-height: 1.65;
}

.recommendation-card {
  display: grid;
  grid-template-columns: minmax(220px, 0.5fr) minmax(0, 1fr);
  gap: 24px;
  align-items: center;
  margin-top: 22px;
  padding: 26px 28px;
  border-radius: var(--radius-large);
  background:
    radial-gradient(circle at bottom left, rgba(31, 79, 122, 0.12), transparent 20rem),
    #ffffff;
}

.recommendation-card h3 {
  margin: 0;
  font-size: 1.45rem;
  letter-spacing: -0.035em;
}

.recommendation-card p {
  margin: 0;
  color: #475467;
  line-height: 1.7;
}

.recommendation-kicker {
  margin-bottom: 12px;
}

.table-card {
  overflow: hidden;
  border-radius: var(--radius-large);
  background: var(--surface);
}

table {
  width: 100%;
  border-collapse: collapse;
}

thead {
  background: #f8fafc;
}

th {
  padding: 17px 18px;
  color: #475467;
  font-size: 0.82rem;
  font-weight: 900;
  letter-spacing: 0.02em;
  text-align: left;
  text-transform: uppercase;
}

td {
  padding: 18px;
  border-top: 1px solid var(--border);
  color: #344054;
  font-size: 0.95rem;
}

.table-status.approved {
  color: var(--green);
  background: var(--green-soft);
}

.table-status.pending {
  color: var(--orange);
  background: var(--orange-soft);
}

.booking-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.25fr) minmax(310px, 0.65fr);
  gap: 22px;
  align-items: stretch;
}

.booking-card,
.rules-card {
  padding: 28px;
  border-radius: var(--radius-large);
  background: var(--surface);
}

.booking-text {
  margin: 0 0 20px;
  color: var(--text-muted);
  line-height: 1.65;
}

.iframe-placeholder {
  display: grid;
  min-height: 340px;
  place-items: center;
  padding: 28px;
  border: 1.5px dashed #b7c5d7;
  border-radius: var(--radius-medium);
  color: var(--text-muted);
  background:
    linear-gradient(135deg, rgba(31, 79, 122, 0.08), transparent),
    #f8fafc;
  text-align: center;
}

.iframe-placeholder span {
  display: inline-flex;
  margin-bottom: 12px;
  padding: 7px 12px;
  border-radius: 999px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 0.78rem;
  font-weight: 900;
}

.iframe-placeholder strong {
  display: block;
  margin-bottom: 8px;
  color: #111827;
  font-size: 1.1rem;
}

.iframe-placeholder p {
  max-width: 560px;
  margin: 0 auto;
  line-height: 1.6;
}

.rules-card h2 {
  margin: 0 0 16px;
  font-size: 1.6rem;
  letter-spacing: -0.035em;
}

.rules-card ul {
  display: grid;
  gap: 13px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.rules-card li {
  position: relative;
  padding-left: 26px;
  color: #475467;
  line-height: 1.55;
}

.rules-card li::before {
  position: absolute;
  top: 8px;
  left: 0;
  width: 10px;
  height: 10px;
  content: "";
  border-radius: 999px;
  background: var(--primary);
}

.admin-card {
  display: flex;
  justify-content: space-between;
  gap: 24px;
  align-items: center;
  padding: 28px;
  border-radius: var(--radius-large);
  color: var(--text-light);
  background:
    radial-gradient(circle at top right, rgba(59, 130, 246, 0.32), transparent 20rem),
    #111827;
}

.admin-kicker {
  color: #bfdbfe;
  background: rgba(219, 234, 254, 0.13);
}

.admin-card h2 {
  margin: 0 0 8px;
  font-size: 1.6rem;
  letter-spacing: -0.035em;
}

.admin-card p {
  max-width: 740px;
  margin: 0;
  color: #cbd5e1;
  line-height: 1.65;
}

.footer {
  display: flex;
  justify-content: space-between;
  gap: 24px;
  align-items: center;
  padding: 34px 7vw 46px;
  color: var(--text-muted);
}

.footer-main {
  display: flex;
  gap: 16px;
  align-items: center;
}

.footer-logo {
  width: 62px;
  height: 62px;
  object-fit: contain;
}

.footer p,
.footer span {
  margin: 0;
}

.footer p {
  margin-bottom: 4px;
  font-weight: 800;
  color: #344054;
}

.footer-support {
  display: flex;
  gap: 12px;
  align-items: center;
}

.footer-support span {
  color: var(--text-muted);
  font-size: 0.76rem;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.footer-fapesp {
  height: 34px;
  width: auto;
  object-fit: contain;
}

@media (max-width: 1180px) {
  .institutional-header {
    display: block;
  }

  .institutional-logo-row {
    justify-content: flex-start;
    margin-top: 18px;
  }

  .support-logo-box {
    padding-left: 0;
    border-left: none;
  }

  .about-meta-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 1100px) {
  .spec-metrics {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 980px) {
  .hero-section,
  .status-grid,
  .spec-grid,
  .booking-layout,
  .recommendation-card {
    grid-template-columns: 1fr;
  }

  .section-header {
    display: block;
  }

  .section-header p {
    margin-top: 8px;
    text-align: left;
  }

  .admin-card {
    display: block;
  }

  .admin-card .button {
    margin-top: 22px;
  }
}

@media (max-width: 760px) {
  .institutional-header,
  .hero-section,
  .content-section {
    padding-left: 20px;
    padding-right: 20px;
  }

  .institutional-main {
    display: block;
    min-width: 0;
  }

  .logo-geocis {
    width: 76px;
    height: 76px;
    margin-bottom: 12px;
  }

  .institutional-logo-row {
    gap: 14px;
  }

  .logo-solos {
    height: 42px;
  }

  .logo-esalq {
    height: 38px;
    max-width: 220px;
  }

  .logo-usp {
    height: 36px;
    max-width: 120px;
  }

  .logo-fapesp {
    height: 32px;
    max-width: 140px;
  }

  .hero-section {
    padding-top: 22px;
  }

  .hero-content,
  .hero-summary-card,
  .computer-card,
  .booking-card,
  .rules-card,
  .admin-card,
  .spec-card,
  .recommendation-card,
  .about-lab-card {
    border-radius: 22px;
  }

  .hero-content {
    padding: 26px;
  }

  .about-meta-grid,
  .computer-info-grid,
  .spec-metrics {
    grid-template-columns: 1fr;
  }

  .spec-card-top {
    display: block;
  }

  .spec-chip {
    margin-top: 14px;
  }

  .table-card {
    overflow-x: auto;
  }

  table {
    min-width: 820px;
  }

  .footer {
    display: block;
    padding-left: 20px;
    padding-right: 20px;
  }

  .footer-main {
    align-items: flex-start;
  }

  .footer-support {
    margin-top: 20px;
  }
}
)"

writeLines(html_content, index_file, useBytes = TRUE)
writeLines(css_content, css_file, useBytes = TRUE)

message("Arquivos atualizados:")
message(index_file)
message(css_file)

utils::browseURL(normalizePath(index_file, winslash = "/", mustWork = TRUE))