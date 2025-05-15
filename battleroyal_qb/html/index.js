$(function () {
    $("body").hide();
    $('#energy').hide();
    window.addEventListener('message', function(event) {
        let text = document.getElementById("text")
        let text2 = document.getElementById("kills")
        let winningsound = this.document.getElementById("winningsound")
        let lootsound = this.document.getElementById("lootsound")
        let text3 = document.getElementById("players")
        let textwins = document.getElementById("winstop")
        let redbull = document.getElementById("myBar");
        var item = event.data;
        if (item.type === "text") {
            $("body").fadeIn();
            $("#text").fadeIn();
            if (item.text == 'Victory') {
                winningsound.load()
                winningsound.play();
                winningsound.volume = 0.28;
                $('#energy').hide();
            }
            text.innerText = item.text
            setTimeout(function() {
                $("#text").fadeOut(); 
                winningsound.pause();
            }, 4800);
        }    


        if (item.type === 'redbull') {
            $('#energy').show();
            redbull.style.width = item.Redbull + '%';
        }

        if (item.type == 'lobbyscreen') {
            $('#energy').hide();
            $("body").fadeIn();
            $('#leaderboarddiv').hide();
            $('#hud').hide();
            $('#container').hide();
            $('#lobbyscreen').show();
            textwins.innerText = 'WINS: ' + item.wins
        }

        if (item.type === "ui") {
            $('#lobbyscreen').hide();
            $("body").fadeIn();
            $('#hud').fadeIn();
            $('#container').fadeIn();
            if (item.Kills == undefined) {
                text2.innerText = 'KILLS : 0'
            }else{
                text2.innerText = 'KILLS : ' + item.Kills
            }
            if (item.Playersingame == undefined) {
                text3.innerText = 'ALIVE'
            }else {
                text3.innerText = 'ALIVE : ' + item.Playersingame + '/48'
            }

        }  
        
        if (item.type === "uihide") {
            $("body").fadeOut();
            $('#energy').hide();
        }   

        if (item.type === "loot") {
            lootsound.play();
        }   
         

        if (item.type === "topdata") {
            var nameDiv = $('<div>').text(item.name);
            var winsDiv = $('<div>').text(item.wins);
            var topDiv = $('<div>').text(item.Topid + ".");
            $('#namep').append(nameDiv);
            $('#winsp').append(winsDiv);
            $('#topnumberid').append(topDiv);
        }  

        if (item.type === "datacareer") {
            document.getElementById("mplayedct").innerHTML = item.matchesplayed
            document.getElementById("winsct").innerHTML = item.wins
            document.getElementById("killst").innerHTML = item.kills
        }  
    })   
})





function play(){
    $('#leaderboarddiv').hide();
    $('#careerdiv').hide();
    $('#gameselector').fadeIn();
}

function join(){
    $.post(`https://${GetParentResourceName()}/joingame`);
}

function leave(){
    $("body").hide();
    $.post(`https://${GetParentResourceName()}/leavelobby`);
    $('#energy').hide();
}

function board(){
    $.post(`https://${GetParentResourceName()}/dataleaderboard`);
    $('#gameselector').hide();
    $('#careerdiv').hide();
    $('#leaderboarddiv').fadeIn();
    $('#namep').html("");
    $('#topnumberid').html("");
    $('#winsp').html("");
}

function career(){
    $.post(`https://${GetParentResourceName()}/datacareer`);
    $('#gameselector').hide();
    $('#leaderboarddiv').hide();
    $('#careerdiv').fadeIn();
}

