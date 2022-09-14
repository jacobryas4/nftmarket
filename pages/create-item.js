import { useState } from 'react'
import { ethers } from 'ethers'
import { create as ipfsHttpClient } from 'ipfs-http-client'
import { useRouter } from 'next/router'
import Web3Modal from 'web3modal'

const client = ipfsHttpClient('https://ipfs.infura.io:5001/api/v0')

import {
    nftaddress,
    nftmarketaddress
} from '../config'

import NFT from '../artifacts/contracts/NFT.sol/NFT.json'
import Market from '../artifacts/contracts/NFTMarket.sol/NFTMarket.json'

export default function CreateItem() {
    const [fileUrl, setFileUrl] = useState(null)
    const [formInput, updateFormInput] = useState({ price: '', name: '', description: '' })
    const router = useRouter()

    async function onChange(e) {
        const file = e.target.files[0]
        try {
            const added = await client.add(
                file,
                {
                    progress: (prog) => console.log(`received: ${prog}`)
                }
            )
            const url = `https://ipfs.infura.io/ipfs/${added.path}`
            setFileUrl(url)
        } catch(e) {
            console.log(e)
        }
    }

    async function createItem() {
        const { name, description, price } = formInput
        if (!name || !description || !price || !fileUrl) return 

        const data  = JSON.stringify({
            name, description, image: fileUrl
        })

        try {
            const added = await client.add(data)
            const url = `https://ipfs.infura.io/ipfs/${added.path}`
            // after file is in IPFS, save it on Polygon
            createSale(url) // is this right? jacob b
        } catch(err) {
            console.log('Error uploading file: ', err)
        }
    }

    async function createSale() {

        // connect to user wallet, get signer
        const web3Modal = new Web3Modal()
        const connection = await web3Modal.connect()
        const provider = new ethers.providers.Web3Provider(connection)
        const signer = provider.getSigner()

        // interact with NFT contract
        let contract = new ethers.Contract(nftaddress, NFT.abi, signer)
        let transaction = await contract.createToken(url)

        // wait for transaction to succeed
        let tx = await transaction.wait()

        // get token id 
        let event = tx.events[0]
        let value = event.args[2]
        let tokenId = value.toNumber()

        // convert to a readable price 
        const price = ethers.utils.parseUnits(formInput.price, 'ether')

        // move contract reference from NFT to market address
        contract = new ethers.Contract(nftmarketaddress, Market.abi, signer)

        // get the listing price 
        let listingPrice = await contract.getListingPrice()
        listingPrice = listingPrice.toString()

        // interact with market address contract
        transaction = await contract.createMarketItem(
            nftaddress, tokenId, price, { value: listingPrice }
        )
        await transaction.wait()
        router.push('/')

    }

    return (
        <div className="flex justify-center">
            <div className="w-1/2 flex flex-col pb-12">
                
            </div>
        </div>
    )

}