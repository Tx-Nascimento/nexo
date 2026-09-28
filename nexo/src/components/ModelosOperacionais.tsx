import { useState } from 'react'
import { modelosOperacionais } from '../data/modelosOperacionais'
import './PainelOperacional.css'
export default function ModelosOperacionais() {
  const [setor,setSetor]=useState('')
  const [busca,setBusca]=useState('')
  const [id,setId]=useState('compras')
  const lista=modelosOperacionais.filter(m=>(!setor || m.setor===setor) && `${m.titulo} ${m.operacao}`.toLocaleLowerCase('pt-BR').includes(busca.toLocaleLowerCase('pt-BR')))
  const selecionado=lista.find(m=>m.id===id) || lista[0]
  function baixar() {
    if (!selecionado) return
    const blob=new Blob([selecionado.conteudo],{type:'text/plain;charset=utf-8'})
    const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url;a.download=`nexo-modelo-${selecionado.id}.txt`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)
  }
  return <div className="op-panel"><div className="op-filter-strip"><label>Área do modelo<select value={setor} onChange={e=>setSetor(e.target.value)}><option value="">Todas</option>{[...new Set(modelosOperacionais.map(m=>m.setor))].map(s=><option key={s}>{s}</option>)}</select></label><label>Buscar modelo<input value={busca} onChange={e=>setBusca(e.target.value)} placeholder="Título ou operação"/></label></div><p className="op-caption">Documentos utilizáveis para adaptar à empresa. São modelos, não procedimentos já aprovados. Baixe, revise e cadastre a versão aprovada no repositório.</p><div className="op-repository"><nav className="op-repository-list" aria-label="Modelos disponíveis">{lista.map(m=><button key={m.id} aria-pressed={selecionado?.id===m.id} onClick={()=>setId(m.id)}>{m.titulo}<small>{m.setor} · {m.operacao}</small></button>)}</nav>{selecionado ? <article className="op-card"><div className="op-section-heading"><h2>{selecionado.titulo}</h2><button onClick={baixar}>Baixar modelo</button></div><div className="op-doc-content">{selecionado.conteudo}</div></article> : <p>Nenhum modelo encontrado.</p>}</div></div>
}
