// Installation is user-initiated; no automatic navigation or interrupted tasks.
const button = document.querySelector('#install-app');
const standalone = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
let installPrompt = null;
function updateButton() { button.hidden = standalone(); }
updateButton();
window.addEventListener('beforeinstallprompt', event => {
  event.preventDefault(); installPrompt = event; updateButton();
});
window.addEventListener('appinstalled', () => { installPrompt = null; updateButton(); });
matchMedia('(display-mode: standalone)').addEventListener('change', updateButton);
button.addEventListener('click', async () => {
  if (installPrompt) {
    button.disabled = true;
    try { await installPrompt.prompt(); await installPrompt.userChoice; }
    finally { installPrompt = null; button.disabled = false; updateButton(); }
    return;
  }
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const dialog = document.createElement('dialog');
  const heading = document.createElement('h2'); heading.textContent = 'Instalar WMS';
  const text = document.createElement('p'); text.className = 'install-help';
  text.textContent = ios
    ? 'No Safari, abra Compartilhar e escolha Adicionar à Tela de Início. Depois, abra o WMS pelo ícone criado.'
    : 'Abra o menu do navegador e escolha Instalar aplicativo ou Adicionar à tela inicial. No computador, procure o ícone de instalação na barra de endereço. Se a opção ainda não aparecer, use a página pelo navegador enquanto a instalação é validada neste dispositivo.';
  const detail = document.createElement('p'); detail.className = 'sub';
  detail.textContent = 'Instalar cria um atalho em tela cheia. Seu acesso ao WMS continua exigindo um usuário cadastrado. Na demonstração, os dados são fictícios.';
  const close = document.createElement('button'); close.className = 'primary'; close.textContent = 'Entendi';
  close.addEventListener('click', () => dialog.close());
  dialog.append(heading, text, detail, close); document.body.append(dialog);
  dialog.addEventListener('close', () => dialog.remove(), {once: true}); dialog.showModal();
});
