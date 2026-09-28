import type { ReactNode } from 'react'
import type { DadosUsuario, Pagina } from '../types'
import './Layout.css'

type Props = { usuario: DadosUsuario; pagina: Pagina; navegar: (pagina: Pagina) => void; sair: () => void; saindo?: boolean; children: ReactNode }
export default function Layout({ usuario, pagina, navegar, sair, saindo = false, children }: Props) {
  const diretor = ['ADMIN', 'DIRETORIA'].includes(usuario.perfil)
  const itens: [Pagina, string][] = [['central', diretor ? 'Visão geral' : 'Minha central'], ['operacoes', 'Operações'], ['demandas', 'Demandas'], ['processos-geral', 'Processos'], ['pessoas-geral', 'Equipe'], ['documentos', 'Documentos'], ['indicadores', 'Indicadores']]
  if (diretor) itens.push(['administracao', 'Cadastros'])
  const administrativas = ['administracao','empresas','setores','cargos','pessoas','perfis','processos','cadastro-operacoes','responsabilidades','recorrencias']
  return <div className="nexo-shell">
    <a className="nexo-skip" href="#conteudo">Ir para o conteúdo</a>
    <header className="nexo-topbar"><div className="nexo-topline">
      <button className="nexo-wordmark" onClick={() => navegar('central')} aria-label="NEXO — início"><span className="nexo-mark">N</span><strong>NEXO<small>Gestão de operações</small></strong></button>
      <div className="nexo-account"><span className="nexo-avatar" aria-hidden="true">{usuario.nome.slice(0, 1)}</span><span><strong>{usuario.nome}</strong><small>{usuario.perfil}</small></span><button className="nexo-signout" onClick={sair} disabled={saindo}>{saindo ? 'Saindo…' : 'Sair'}</button></div>
    </div><nav className="nexo-topnav" aria-label="Navegação principal">{itens.map(([destino, rotulo]) => {
      const ativo = destino === pagina || destino === 'administracao' && administrativas.includes(pagina)
      return <button key={destino} aria-current={ativo ? 'page' : undefined} className={ativo ? 'selected' : ''} onClick={() => navegar(destino)}>{rotulo}</button>
    })}</nav></header>
    <main id="conteudo" tabIndex={-1} className="main-content">{children}</main>
    <footer className="nexo-footer">NEXO <span>Clareza para decidir. Organização para entregar.</span></footer>
  </div>
}
